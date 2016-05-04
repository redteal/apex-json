public class RT_JsonMapper {

	/** This Processor instance is passed into to each call
	 *  of IAction.exec to provide context.
	 */
	public final Processor processor;
	
	public final Config conf;
	
	public RT_Json.JsonNode root;
	
	public Map<Id, SObject> records;
	
	private final RT_DirectedGraph graph;
	
	/** Object nodes, keyed by their ref_id atribute, where this attribute exists.
	 */
	public final Map<String, RT_Json.JsonNode> refSources;
	
	/** Nodes where a reference has been found in a field, mapped by ref_id.
	 *  Synatx: "{ref_id.FieldName}"
	 */
	public final Map<String, Set<RT_Json.JsonNode>> references;
	
	/** Master-detail relationship mappings of master (parent) to detail (children).
	 */
	public final Map<RT_Json.JsonNode, List<RT_Json.JsonNode>> relationships;
	
	/** Flag if any DML exceptions have occurred while parsing.
	 */
	public Boolean hasErrors;
	
	public List<Exception> errors;
	
	/** Capture any nodes that depend on an exception-causing node.
	 */
	public final Set<RT_Json.JsonNode> abortedNodes;
	
	public RT_JsonMapper(Config conf) {
		this.conf = conf;
		processor = new Processor(this);
		records = new Map<Id, SObject>();
		references = new Map<String, Set<RT_Json.JsonNode>>();
		refSources = new Map<String, RT_Json.JsonNode>();
		relationships = new Map<RT_Json.JsonNode, List<RT_Json.JsonNode>>();
		graph = new RT_DirectedGraph();
		hasErrors = false;
		errors = new List<Exception>();
		abortedNodes = new Set<RT_Json.JsonNode>();
	}
	
	public RT_JsonMapper() {
		this(new Config());
	}
	
	public void reset() {
		root = null;
		hasErrors = false;
		records.clear();
		errors.clear();
		processor.reset();
		references.clear();
		refSources.clear();
		relationships.clear();
		graph.clear();
		abortedNodes.clear();
	}
	
	public Map<Id, SObject> parse(String jsonString) {
		try {
			root = readTree(jsonString);
			processor.exec(conf.onBeforeParse, root);
			records.putAll(parse(root));
			processor.exec(conf.onAfterParse, root);
		}
		catch (Exception e) {
			errors.add(e);
			records = new Map<Id, SObject>();
		}
		return records;
	}
	
	public RT_Json.JsonNode readTree(String jsonString) {
		reset();
		JSONParser parser = JSON.createParser(jsonString);
		root = parseTree(conf.readers.readAll(parser));
		graphNodes(root);
		graphEdges();
		return root;
	}
	
	@testVisible
	private Map<Id, SObject> parse(RT_Json.JsonNode root) {
	
		// Lets first inject any references that don't depend on an SObject
		List<RT_Json.JsonNode> objectSources = new List<RT_Json.JsonNode>();
		for (RT_Json.JsonNode refSource : refSources.values()) {
			if (!refSource.isSObject()) {
				objectSources.add(refSource);
			}
		}
		injectObjectRefs(objectSources);
		
		// Upsert SObjectNode records and inject refs/relations into their dependencies
		Savepoint sp = Database.setSavepoint();
		Map<Id, SObject> records = new Map<Id, SObject>();
		List<RT_Json.JsonNode> sortedNodes = RT_Json.asList(graph.toposort(), RT_Json.NodeType.SOBJECT_T);
		
		for (RT_Json.JsonNode node : sortedNodes) {
			if (!abortedNodes.contains(node)) {
				SObject record = commitNode(node);
				if (record != null) {
					records.put(record.Id, record);
					injectObjectRefs(node);
					injectRelationshipIds(node);
				}
			}
		}
		
		// Rollback if we're only validating
		if (conf.validateOnly || hasErrors) {
			Database.rollback(sp);
		}
		return records;
	}
	
	private SObject commitNode(RT_Json.JsonNode node) {
		SObject record;
		System.debug('Committing node: ' + node.get('Name'));
		if (node.isSObject() && !abortedNodes.contains(node)) {
			try {
				if (processor.exec(conf.onBeforeUpsert, node)) {
					record = (SObject) node.value();
					// Set DML Options for this node
					record.setOptions(conf.dmlOptions);
					// Remove any ignored fields from the record
					record = RT_JsonUtil.unsetFields(record, conf.overrides.ignoredFields);
					// Commit the record
					upsert record;
					node.put('Id', record.Id);
					processor.exec(conf.afterUpsert, node);
				}
			}
			catch (Exception e) {
				hasErrors = true;
				if (e.getMessage().contains('INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY')) {
					if (record.Id != null) {
						e.setMessage(e.getMessage().replaceFirst(record.Id, ''));
					}
					for (RT_Json.JsonNode n : node.elements()) {
						if (e.getMessage().contains(n.asText())) {
							e.setMessage('Failed to update field ' + node.getSObjectType() + '.' + n.property +
										 ' with value ' + n.asText() + ': User either does not have access to' +
										 ' to the referenced record, or a record with that Id does not exist.');
							break;
						}
					}
				}
				record = null;
				abortNode(node);
				errors.add(e);
			}
		}
		return record;
	}
	
	/** Aborts DML operations on a node's dependencies if a DML error has occured on said node.
	 */
	private void abortNode(RT_Json.JsonNode node) {
		System.debug('Aborting dependency in ' + node.ancestor(2).property +
					 ' with name ' + node.get('Name') + ' at index ' + node.index);
		abortedNodes.add(node);
		Set<RT_Json.JsonNode> dependencies = new Set<RT_Json.JsonNode>();
		Set<RT_Json.JsonNode> refNodes = references.get(node.getRefId());
		if (refNodes != null) {
			dependencies.addAll(refNodes);
		}
		List<RT_Json.JsonNode> relNodes = relationships.get(node);
		if (relNodes != null) {
			dependencies.addAll(relNodes);
		}
		for (RT_Json.JsonNode dependency : dependencies) {
			if (!abortedNodes.contains(dependency)) {
				abortNode(dependency);
			}
		}
		System.debug('');
	}
	
	private void injectObjectRefs(List<RT_Json.JsonNode> sources) {
		for (RT_Json.JsonNode source : sources) {
			injectObjectRefs(source);
		}
	}
	
	private void injectObjectRefs(RT_Json.JsonNode source) {
		String refId = source.getRefId();
		Set<RT_Json.JsonNode> dependencies = references.get(refId);
		if (dependencies != null) {
			for (RT_Json.JsonNode dependency : dependencies) {
				if (abortedNodes.contains(dependency)) {
					dependencies.remove(dependency);
				}
				else {
					Map<String, Set<String>> dependencyRefs = dependency.getRefs();
					Set<String> dependencyFields = dependencyRefs.get(refId);
					if (dependencyFields != null) {
						for (String field : dependencyFields) {
							injectDependencyValue(source, dependency, field);
							dependencyFields.remove(field);
						}
						if (dependencyFields.isEmpty()) {
							dependencyRefs.remove(refId);
						}
					}
					if (dependencyRefs.isEmpty()) {
						dependencies.remove(dependency);
					}
				}
			}
			if (dependencies.isEmpty()) {
				references.remove(refId);
				refSources.remove(refId);
			}
		}
		else {
			refSources.remove(refId);
		}
	}
	
	private void injectDependencyValue(RT_Json.JsonNode source, RT_Json.JsonNode dependency, String field) {
		RT_Json.JsonNode depFieldNode = dependency.get(field);
		String var = depFieldNode.asText();
		if (var.startsWith('{') && var.endsWith('}') && var.contains('.')) {
			String sourceField = var.substringBetween('.', '}');
			RT_Json.JsonNode newValue;
			if (source.isSObject()) {
				SObject record = (SObject) source.value();
				Object value = record.get(sourceField);
				if (value != null) {
					newValue = RT_Json.textNode(String.valueOf(value));
				}
			}
			if (newValue == null) {
				newValue = source.get(sourceField).copy();
			}
			dependency.put(field, newValue);
		}
	}
	
	private void injectRelationshipIds(RT_Json.JsonNode master) {
		Id masterId = master.recordId();
		List<RT_Json.JsonNode> detailNodes = relationships.get(master);
		if (detailNodes != null) {
			for (RT_Json.JsonNode detail : detailNodes) {
				injectMasterId(detail, masterId);
			}
		}
	}
	
	private void injectMasterId(RT_Json.JsonNode detail, Id masterId) {
		Map<String, ChildRelationship> childRels = RT_JsonUtil.getChildRelationships(masterId.getSobjectType());
		ChildRelationship childRel;
		
		RT_Json.JsonNode parent = detail.parent;
		while (parent != null) {
			if (parent.isObjectValue() && childRels.containsKey(parent.property.toLowerCase())) {
				childRel = childRels.get(parent.property.toLowerCase());
				break;
			}
			parent = parent.parent;
		}
		if (childRel != null) {
			RT_Json.JsonNode n = RT_Json.textNode(masterId);
			detail.put('' + childRel.getField(), n);
		}
	}
	
	private void graphNodes(RT_Json.JsonNode node) {
		// Add all possible nodes
		graph.addNode(node);
		for (RT_Json.JsonNode leaf : node.elements()) {
			graphNodes(leaf);
		}
	}
	
	private void graphEdges() {
		// Add master-detail relationships
		for (RT_Json.JsonNode master : relationships.keySet()) {
			for (RT_Json.JsonNode detail : relationships.get(master)) {
				graph.addEdge(master, detail);
			}
		}
		// Add ref dependencies -> ref sources
		for (String refId : refSources.keySet()) {
			RT_Json.JsonNode source = refSources.get(refId);
			if (references.containsKey(refId)) {
				for (RT_Json.JsonNode dependency : references.get(refId)) {
					graph.addEdge(source, dependency);
				}
			}
		}
	}
	
	@testVisible
	private RT_Json.JsonNode parseTree(RT_Json.JsonNode node) {
		if (node.isTextual()) {
			node = parseTextNode(node);
		}
		else if (node.isObject()) {
			node = parseObjectNode(node);
		}
		
		// Traverse the current node's children, if any.
		for (RT_Json.JsonNode leaf : node.elements().clone()) {
			parseTree(leaf);
		}
		return node;
	}
	
	private RT_Json.JsonNode parseTextNode(RT_Json.JsonNode node) {
		RT_Json.JsonNode parent = node.ancestor(1);
		if (parent.isSObject()) {
			String text = node.asText();
			if (text.startsWith('{') && text.endsWith('}')) {
				String refId = text.substringBetween('{', '.');
				if (String.isNotBlank(refId)) {
					Set<RT_Json.JsonNode> refNodes = references.get(refId);
					if (refNodes == null) {
						references.put(refId, refNodes = new Set<RT_Json.JsonNode>());
					}
					refNodes.add(parent);
					parent.addRef(node.property, refId);
				}
			}
		}
		return node;
	}
	
	private RT_Json.JsonNode parseObjectNode(RT_Json.JsonNode node) {
		Boolean isDetailRel = false;
		
		// Master-detail relationships can be defined in a "records" array property within an object property.
		// sObject node <- relationship obj <- records array <- this obj
		RT_Json.JsonNode arrNode = node.ancestor(1); // the records array
		RT_Json.JsonNode relNode = node.ancestor(2); // the object (field) holding the array
		RT_Json.JsonNode masterNode = node.ancestor(3); // the master SObject
		String relName = relNode.property;
		
		// We will auto-inject type attribute of detail record if master represents an SObject.
		if (arrNode.isArray() && relNode.isObject() && masterNode.isSObject() && relName != null) {
			// Must check that relName is a valid relationship on its own parent.
			SObjectType stype = RT_JsonUtil.getSObjectType(masterNode.get('attributes').get('type').asText());
			ChildRelationship childRel = RT_JsonUtil.getChildRelationships(stype).get(relName.toLowerCase());
			if (childRel != null) {
				SObjectType childSType = childRel.getChildSObject();
				if (childSType != null) {
					RT_Json.JsonNode attrNode = node.get('attributes');
					if (!attrNode.isObject()) {
						attrNode = node.putObject('attributes');
					}
					attrNode.put('type', '' + childSType);
					isDetailRel = true;
				}
			}
		}
		
		// If the current node represents an SObject, lets convert it to an SObjectNode.
		RT_Json.JsonNode typeNode = node.get('attributes').get('type');
		if (!typeNode.isMissingNode()) {
			// Reassign any configured overrides
			String srcType = typeNode.asText();
			SObjectType destType = conf.overrides.stypes.get(srcType);
			if (destType != null) {
				typeNode.parent.put('type', '' + destType);
			}
			Set<String> fieldExclusions = conf.overrides.exclusions.get(srcType);
			if (fieldExclusions != null) {
				for (String exclusion : fieldExclusions) {
					node.remove(exclusion);
				}
			}
			Map<String, SObjectField> fieldOverrides = conf.overrides.sfields.get(srcType);
			if (fieldOverrides != null) {
				for (String srcField : fieldOverrides.keySet()) {
					RT_Json.JsonNode n = node.get(srcField);
					if (!n.isMissingNode() && n.property != '' + fieldOverrides.get(srcField)) {
						n.moveTo(n.parent, null, '' + fieldOverrides.get(srcField));
					}
					String srcRef = srcField.replaceAll('__c$', '__r');
					String newSrcRef = ('' + fieldOverrides.get(srcField)).replaceAll('__c$', '__r');
					RT_Json.JsonNode srcRefNode = node.get(srcRef);
					if (!srcRefNode.isMissingNode() && srcRefNode.property != newSrcRef) {
						srcRefNode.moveTo(srcRefNode.parent, null, newSrcRef);
					}
				}
			}
		}
		// Convert to SObjectNode
		if (node.isObject() || node.isSObject()) {
			RT_Json.JsonNode newNode = node.toSObjectNode();
			if (!newNode.isMissingNode()) {
				node = newNode;
				if (conf.strictMode && node.isSObject()) {
					Set<String> nonSchemaProperties = ((RT_Json.SObjectNode) node).nonSchemaProperties;
					if (!nonSchemaProperties.isEmpty()) {
						throw new RT_Json.JsonParsingException(
							'Writing of JSON properties failed. Fields do not exist in Schema for type ' +
							node.getSobjectType() + ': ' + RT_JsonUtil.join(nonSchemaProperties, ', '));
					}
				}
			}
		}
		
		// If the current node is the detail side of a master-detail relationship, link it to the master.
		if (isDetailRel) {
			List<RT_Json.JsonNode> detailRels = relationships.get(masterNode);
			if (detailRels == null) {
				relationships.put(masterNode, detailRels = new List<RT_Json.JsonNode>());
			}
			detailRels.add(node);
		}
		
		// Store ref_id if there is one
		String refId = node.getRefId();
		if (String.isNotBlank(refId)) {
			refSources.put(refId, node);
		}
		return node;
	}
	
	/** Primary mapper configuration container.
	 */
	public class Config {
	
		/** DML Operation Validation (default: true)
		 *  If true, all DML operations will be rolled back after parsing
		 *  is complete.
		 */
		public Boolean validateOnly;
		
		/** Strict mode (default: false)
		 *  If true, an error will be thrown if any fields are provided that
		 *  are not defined in the schema.
		 */
		public Boolean strictMode;
		
		/** DML Grouping (default: true)
		 *  If true, SObjectNode records of the same type will be grouped
		 *  together in DML operations. Dependency ordering is taken into
		 *  account with groupings; i.e. a type may have multiple groupings.
		 */
		public Boolean groupDml;
		
		/** Before Parse Action (default: no-op)
		 *  Define custom code to execute after the node tree has been constructed,
		 *  but before the tree is parsed. Provides an opportunity to read or modify
		 *  any nodes before converting ObjectNodes into SObjectNodes and DML.
		 */
		public IAction onBeforeParse;
		
		/** After Parse Action (default: no-op)
		 *  Define custom code to execute after node tree is parsed and DML operations are complete.
		 */
		public IAction onAfterParse;
		
		/** Before Upsert Action (default: no-op)
		 *  Define custom code to execute immediately before upserting a
		 *  group of SObjectNode records.
		 */
		public IAction onBeforeUpsert;
		
		/** After Upsert Action (default: no-op)
		 *  Define custom code to execute immediately after upserting a
		 *  group of SObjectNode records.
		 */
		public IAction afterUpsert;
		
		/** Token Readers (default: standard readers)
		 *  Configures token readers used for creating JsonNode instances.
		 */
		public RT_Json.TokenReaders readers;
		
		/** SObject Overrides (default: none)
		 *  Configures overrides and exclusions of names of incoming SObject
		 *  types and fields.
		 */
		public SObjectOverrides overrides;
		
		/** DML Options (system default)
		 */
		public Database.DMLOptions dmlOptions;
		
		public Config() {
			validateOnly = true;
			strictMode = false;
			groupDml = true;
			onBeforeParse = new Noop();
			onAfterParse = new Noop();
			onBeforeUpsert = new Noop();
			afterUpsert = new Noop();
			readers = RT_Json.TOKEN_READERS;
			overrides = new SObjectOverrides();
			dmlOptions = new Database.DMLOptions();
		}
	}
	
	/** Configuration container for overrides and exclusions of
	 *  names on incoming SObject types and fields.
	 */
	public class SObjectOverrides {
	
		public Map<String, SObjectType> stypes;
		public Map<String, Map<String, SObjectField>> sfields;
		public Map<String, Set<String>> exclusions;
		public Set<SObjectField> ignoredFields;
		
		public SObjectOverrides() {
			stypes = new Map<String, SObjectType>();
			sfields = new Map<String, Map<String, SObjectField>>();
			exclusions = new Map<String, Set<String>>();
			ignoredFields = new Set<SObjectField>();
		}
		
		/** Given a local SObjectType, overrides types defined on JSON SObjectNodes.
		 */
		public void addOverride(String srcType, SObjectType destType) {
			if (srcType == null || destType == null) {
				throw new NullPointerException('Arguments cannot be null');
			}
			if (srcType != destType + '') {
				stypes.put(srcType, destType);
			}
		}
		
		/** Given a local SObjectField, overrides property names defined on JSON SObjectNodes.
		 */
		public void addOverride(String srcType, String srcField, SObjectField destField) {
			if (srcType == null || srcField == null || destField == null) {
				throw new NullPointerException('Arguments cannot be null');
			}
			if (srcField != destField + '') {
				Map<String, SObjectField> m = sfields.get(srcType);
				if (m == null) {
					sfields.put(srcType, m = new Map<String, SObjectField>());
				}
				m.put(srcField, destField);
			}
		}
		
		/** Given an incoming type and property name, ignore an incoming SObject field.
		 *  By default, we will include all incoming SObjectNode fields.
		 */
		public void addExclusion(String srcType, String srcField) {
			if (srcType == null || srcField == null) {
				throw new NullPointerException('Arguments cannot be null');
			}
			Set<String> ex = exclusions.get(srcType);
			if (ex == null) {
				exclusions.put(srcType, ex = new Set<String>());
			}
			ex.add(srcField);
		}
		
		/** Field will be removed from SObjects immediately before upsertion.
		 */
		public void addIgnoredField(SObjectField field) {
			ignoredFields.add(field);
		}
	}
	
	/** Processes and provides context to IAction instances.
	 */
	public class Processor {
	
		public final RT_JsonMapper mapper;
		public final Config conf;
		public final Map<Object, Object> data;
		public List<RT_Json.JsonNode> nodes;
		
		public Processor(RT_JsonMapper mapper) {
			this.conf = mapper.conf;
			this.mapper = mapper;
			data = new Map<Object, Object>();
			nodes = new List<RT_Json.JsonNode>();
		}
		
		public void reset() {
			data.clear();
			nodes.clear();
		}
		
		public Boolean exec(IAction action, List<RT_Json.JsonNode> nodes) {
			this.nodes.clear();
			this.nodes.addAll(nodes);
			return action.exec(this);
		}
		
		public Boolean exec(IAction action, RT_Json.JsonNode node) {
			return exec(action, new List<RT_Json.JsonNode> {node});
		}
	}
	
	/** Defines an action to take on the given JsonNode.
	 */
	public interface IAction {
		Boolean exec(Processor processor);
	}
	
	/** Implementation of a "No Operation" action.
	 */
	public class Noop implements IAction {
		public Boolean exec(Processor processor) { return true; }
	}
	
	public class NullPointerException extends Exception {}
	
	public class IndexOutOfBoundsException extends Exception {}
}