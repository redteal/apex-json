public class RT_Json {

	@testVisible
	private static final List<JsonNode> NO_NODES = new List<JsonNode>();
	
	@testVisible
	private static final List<String> NO_STRINGS = new List<String>();
	
	@testVisible
	private static final Map<String, JsonNode> NO_FIELDS = new Map<String, JsonNode>();
	
	private static final Map<String, Set<String>> NO_REFS = new Map<String, Set<String>>();
	
	private static final TextNode EMPTY_STRING_NODE = new TextNode('');
	
	public static Map<Set<DisplayType>, RecordWriter> RECORD_WRITERS = new Map<Set<DisplayType>, RecordWriter> {
		null => new NullWriter(),
		RT_JsonUtil.STRING_TYPES => new StringWriter(),
		RT_JsonUtil.BOOLEAN_TYPES => new BooleanWriter(),
		RT_JsonUtil.ID_TYPES => new IdWriter(),
		RT_JsonUtil.INTEGER_TYPES  => new IntegerWriter(),
		RT_JsonUtil.DOUBLE_TYPES => new DoubleWriter(),
		RT_JsonUtil.DATE_TYPES => new DateWriter(),
		RT_JsonUtil.DATETIME_TYPES => new DateTimeWriter()
	};
	
	public static final TokenReaders TOKEN_READERS = new TokenReaders();
	
	static {
		TOKEN_READERS.register(JSONToken.VALUE_STRING, new StringReader());
		TOKEN_READERS.register(JSONToken.VALUE_NULL, new NullReader());
		TOKEN_READERS.register(JSONToken.VALUE_NUMBER_INT, new IntReader());
		TOKEN_READERS.register(JSONToken.VALUE_NUMBER_FLOAT, new FloatReader());
		TOKEN_READERS.register(JSONToken.VALUE_TRUE, new BooleanReader());
		TOKEN_READERS.register(JSONToken.VALUE_FALSE, new BooleanReader());
		TOKEN_READERS.register(JSONToken.START_OBJECT, new ObjectStartReader());
		TOKEN_READERS.register(JSONToken.START_ARRAY, new ArrayStartReader());
		TOKEN_READERS.register(JSONToken.END_OBJECT, new ContainerEndReader());
		TOKEN_READERS.register(JSONToken.END_ARRAY, new ContainerEndReader());
	}
	
	public static ValueNode nullNode() {
		return new NullNode();
	}
	
	public static ValueNode missingNode() {
		return new MissingNode();
	}
	
	public static ValueNode booleanNode(Boolean v) {
		return v == null ? nullNode() : v ? trueNode() : falseNode();
	}
	
	public static ValueNode trueNode() {
		return new BooleanNode(true);
	}
	
	public static ValueNode falseNode() {
		return new BooleanNode(false);
	}
	
	public static ValueNode numberNode(Integer v) {
		return v == null ? nullNode() : new IntNode(v);
	}
	
	public static ValueNode numberNode(Long v) {
		return v == null ? nullNode() : RT_JsonUtil.inIntRange(v) ? numberNode(v.intValue()) : new LongNode(v);
	}
	
	public static ValueNode numberNode(Double v) {
		return v == null ? nullNode() : new DoubleNode(v);
	}
	
	public static ValueNode numberNode(Decimal v) {
		return v == null ? nullNode() : new DecimalNode(v);
	}
	
	public static ValueNode textNode(String v) {
		return v == null ? nullNode() : v.length() == 0 ? EMPTY_STRING_NODE : new TextNode(v);
	}
	
	public static ArrayNode arrayNode() {
		return new ArrayNode();
	}
	
	public static ObjectNode objectNode() {
		return new ObjectNode();
	}
	
	public static List<JsonNode> asList(List<Object> objs, NodeType type) {
		List<JsonNode> nodes = new List<JsonNode>();
		for (Object obj : objs) {
			if (obj instanceof JsonNode) {
				JsonNode node = (JsonNode) obj;
				if (type == null || node.getNodeType() == type) {
					nodes.add(node);
				}
			}
		}
		return nodes;
	}
	
	public abstract class JsonNode implements Comparable {
	
		// Properties
		public JsonNode parent;
		
		public String property {
			get;
			set {
				if (parent != null && !parent.isObject() && !parent.isSObject()) {
					value = null;
				}
				if (value != null) {
					index = null;
				}
				property = value;
			}
		}
		
		public Integer index {
			get;
			set {
				if (parent != null && !parent.isArray()) {
					value = null;
				}
				if (value != null) {
					property = null;
				}
				index = value;
			}
		}
		
		// Standard API
		
		public abstract JSONToken asToken();
		public abstract NodeType getNodeType();
		public abstract Object value();
		public abstract String serialize();
		
		public Boolean isObjectValue() { return property != null; }
		public Boolean isArrayValue() { return index != null; }
		
		public Boolean isValueNode() {
			NodeType type = getNodeType();
			return !(type == NodeType.ARRAY_T || type == NodeType.OBJECT_T || type == NodeType.SOBJECT_T || type == NodeType.MISSING_T);
		}
		
		public Boolean isContainerNode() {
			NodeType type = getNodeType();
			return type == NodeType.OBJECT_T || type == NodeType.SOBJECT_T || type == NodeType.ARRAY_T;
		}
		
		public void moveTo(JsonNode newParent, Integer newIndex, String newProperty) {
			if (newParent == null) {
				return;
			}
			// first, remove this node from current parent
			if (index != null) {
				parent.remove(index);
			}
			else if (property != null) {
				parent.remove(property);
			}
			parent = newParent; // change to new parent
			
			// add this node to the new parent
			if (newIndex == null && newProperty == null) {
				if (parent.isObject()) {
					newProperty = property;
				}
				else if (parent.isArray()) {
					newIndex = parent.size();
				}
			}
			if (parent.isObject() && newProperty != null) {
				parent.put(newProperty, this);
			}
			else if (parent.isArray() && newIndex > -1) {
				parent.set(newIndex, this);
			}
			
			// update index/property properties
			index = newIndex;
			property = newProperty;
		}
		
		public JsonNode ancestor(Integer i) {
			JsonNode n = this;
			while (i-- > 0) {
				if (n.parent == null) {
					break;
				}
				n = n.parent;
			}
			return i < 0 ? n : missingNode();
		}
		
		public Integer depth() {
			return parent != null ? parent.depth() + 1 : 0;
		}
		
		public JsonNode closest(NodeType type) {
			JsonNode n = this;
			while (n.getNodeType() != type) {
				if (n.parent == null) {
					break;
				}
				n = n.parent;
			}
			return n.getNodeType() == type ? n : missingNode();
		}
		
		public Boolean isMissingNode() { return getNodeType() == NodeType.MISSING_T; }
		public Boolean isArray() { return getNodeType() == NodeType.ARRAY_T; }
		public Boolean isObject() { return getNodeType() == NodeType.OBJECT_T; }
		public Boolean isSObject() { return getNodeType() == NodeType.SOBJECT_T; }
		public Boolean isTextual() { return getNodeType() == NodeType.STRING_T; }
		public Boolean isBoolean() { return getNodeType() == NodeType.BOOLEAN_T; }
		public Boolean isNull() { return getNodeType() == NodeType.NULL_T; }
		public Boolean isNumber() { return getNodeType() == NodeType.NUMBER_T; }
		
		public virtual String asText() { return asText('null'); }
		
		public virtual String asText(String defaultValue) {
			Object value = value();
			return value == null ? defaultValue : String.valueOf(value);
		}
		
		public JsonNode at(RT_JsonPointer ptr) {
			if (ptr.matches()) {
				return this;
			}
			JsonNode n = atImpl(ptr);
			return n.isMissingNode() ? n : n.at(ptr.tail());
		}
		
		public JsonNode at(String jsonPtrExpr) {
			return at(RT_JsonPointer.compile(jsonPtrExpr));
		}
		
		private virtual JsonNode atImpl(RT_JsonPointer ptr) { return missingNode(); }
		
		public virtual Integer compareTo(Object o) {
			return 1;
		}
		
		public Boolean equals(Object o) {
			if (o === this) { return true; } // *NOPAD*
			if (o == null) { return false; }
			if (!(o instanceof JsonNode)) { return false; }
			JsonNode n = (JsonNode) o;
			if (getNodeType() != n.getNodeType()) { return false; }
			if (property != n.property) { return false; }
			if (index != n.index) { return false; }
			if (parent != n.parent) { return false; }
			return true;
		}
		
		public Boolean eq(Object o) {
			return o == value();
		}
		
		public Integer hashCode() {
			Integer result = 1;
			result = RT_JsonUtil.hashCode(getNodeType(), result);
			result = RT_JsonUtil.hashCode(value(), result);
			return result;
		}
		
		public override String toString() { return serialize(); }
		
		// ValueNode API
		
		public virtual Integer asInt() { return asInt(0); }
		public virtual Integer asInt(Integer defaultValue) { return defaultValue; }
		public virtual Long asLong() { return asLong(0L); }
		public virtual Long asLong(Long defaultValue) { return defaultValue; }
		public virtual Double asDouble() { return asDouble(Double.valueOf(0.0)); }
		public virtual Double asDouble(Double defaultValue) { return defaultValue; }
		public virtual Decimal asDecimal() { return asDecimal(0.0); }
		public virtual Decimal asDecimal(Decimal defaultValue) { return defaultValue; }
		public virtual Boolean asBoolean() { return asBoolean(false); }
		public virtual Boolean asBoolean(Boolean defaultValue) { return defaultValue; }
		public virtual ValueNode copy() { return nullNode(); }
		
		// NumberNode API
		
		public Integer intValue() { return RT_JsonUtil.toInteger(value(), null); }
		public Long longValue() { return RT_JsonUtil.toLong(value(), null); }
		public Double doubleValue() { return RT_JsonUtil.toDouble(value(), null); }
		public Decimal decimalValue() { return RT_JsonUtil.toDecimal(value(), null); }
		
		public Boolean isIntegralNumber() { return asToken() == JSONToken.VALUE_NUMBER_INT; }
		public Boolean isFloatingPointNumber() { return asToken() == JSONToken.VALUE_NUMBER_FLOAT; }
		
		public Boolean isDecimal() { return numberType() == NumberType.DECIMAL_T; }
		public Boolean isDouble() { return numberType() == NumberType.DOUBLE_T; }
		public Boolean isLong() { return numberType() == NumberType.LONG_T; }
		public Boolean isInt() { return numberType() == NumberType.INTEGER_T; }
		
		public virtual NumberType numberType() { return null; }
		public virtual Boolean booleanValue() { return false; }
		
		// ContainerNode API
		
		public virtual List<JsonNode> elements() { return NO_NODES; }
		public virtual Integer size() { return 0; }
		public virtual void clear() {}
		
		// ObjectNode API
		
		public Boolean has(String property) { return !get(property).isMissingNode(); }
		public JsonNode put(String property, String v) { return put(property, textNode(v)); }
		public JsonNode put(String property, Boolean v) { return put(property, booleanNode(v)); }
		public JsonNode put(String property, Integer v) { return put(property, numberNode(v)); }
		public JsonNode put(String property, Long v) { return put(property, numberNode(v)); }
		public JsonNode put(String property, Double v) { return put(property, numberNode(v)); }
		public JsonNode put(String property, Decimal v) { return put(property, numberNode(v)); }
		
		public virtual Map<String, JsonNode> getMap() { return NO_FIELDS; }
		public virtual Set<String> properties() { return getMap().keySet(); }
		public virtual String getRefId() { return null; }
		public virtual void addRef(String property, String refId) {}
		public virtual Map<String, Set<String>> getRefs() { return NO_REFS; }
		public virtual JsonNode get(String property) { return missingNode(); }
		public virtual JsonNode put(String property, JsonNode value) { return missingNode(); }
		public virtual JsonNode putArray(String property) { return missingNode(); }
		public virtual JsonNode putObject(String property) { return missingNode(); }
		public virtual JsonNode putNull(String property) { return missingNode(); }
		public virtual JsonNode putAll(Map<String, JsonNode> properties) { return missingNode(); }
		public virtual JsonNode putAll(ObjectNode other) { return missingNode(); }
		public virtual JsonNode remove(String property) { return missingNode(); }
		public virtual void removeAll(Set<String> properties) {}
		public virtual void setChildren(Map<String, JsonNode> children) {}
		
		// SObjectNode API
		public virtual SObjectType getSObjectType() { return null; }
		public virtual Id recordId() { return null; }
		public virtual JsonNode toSObjectNode() { return missingNode(); }
		public virtual JsonNode get(SObjectField field) { return missingNode(); }
		public virtual JsonNode put(SObjectField field, JsonNode node) { return missingNode(); }
		public JsonNode put(SObjectField field, String v) { return put(field, textNode(v)); }
		public JsonNode put(SObjectField field, Boolean v) { return put(field, booleanNode(v)); }
		public JsonNode put(SObjectField field, Integer v) { return put(field, numberNode(v)); }
		public JsonNode put(SObjectField field, Long v) { return put(field, numberNode(v)); }
		public JsonNode put(SObjectField field, Double v) { return put(field, numberNode(v)); }
		public JsonNode put(SObjectField field, Decimal v) { return put(field, numberNode(v)); }
		
		
		// ArrayNode API
		
		public Boolean has(Integer ind) { return !get(ind).isMissingNode(); }
		public JsonNode add(Integer value) { return add(numberNode(value)); }
		public JsonNode add(Long value) { return add(numberNode(value)); }
		public JsonNode add(Double value) { return add(numberNode(value)); }
		public JsonNode add(Decimal value) { return add(numberNode(value)); }
		public JsonNode add(String value) { return add(textNode(value)); }
		public JsonNode add(Boolean value) { return add(booleanNode(value)); }
		
		public virtual JsonNode get(Integer index) { return missingNode(); }
		public virtual JsonNode set(Integer index, JsonNode value) { return missingNode(); }
		public virtual JsonNode add(JsonNode value) { return missingNode(); }
		public virtual JsonNode add(Integer index, JsonNode value) { return missingNode(); }
		public virtual JsonNode addArray() { return missingNode(); }
		public virtual JsonNode addObject() { return missingNode(); }
		public virtual JsonNode addNull() { return missingNode(); }
		public virtual JsonNode addArray(Integer index) { return missingNode(); }
		public virtual JsonNode addObject(Integer index) { return missingNode(); }
		public virtual JsonNode addNull(Integer index) { return missingNode(); }
		public virtual JsonNode addAll(ArrayNode other) { return missingNode(); }
		public virtual JsonNode addAll(List<JsonNode> nodes) { return missingNode(); }
		public virtual JsonNode remove(Integer index) { return missingNode(); }
	}
	
	public abstract class ContainerNode extends JsonNode {}
	
	public virtual class ObjectNode extends ContainerNode {
		public Map<String, JsonNode> children;
		public Map<String, Set<String>> refs;
		
		public ObjectNode() {
			this(new Map<String, JsonNode>());
		}
		
		public ObjectNode(Map<String, JsonNode> children) {
			refs = new Map<String, Set<String>>();
			setChildren(children);
		}
		
		public override JSONToken asToken() { return JSONToken.START_OBJECT; }
		public virtual override NodeType getNodeType() { return NodeType.OBJECT_T; }
		public virtual override Object value() { return children; }
		public override List<JsonNode> elements() { return children.values(); }
		public override Map<String, JsonNode> getMap() { return children; }
		public override Integer size() { return children.size(); }
		
		public override String getRefId() {
			String refId = get('attributes').get('ref_id').asText();
			return String.isBlank(refId) ? null : refId;
		}
		
		public override void addRef(String property, String refId) {
			Set<String> fields = refs.get(refId);
			if (fields == null) {
				refs.put(refId, fields = new Set<String>());
			}
			fields.add(property);
		}
		
		public override Map<String, Set<String>> getRefs() {
			return refs;
		}
		
		private override JsonNode atImpl(RT_JsonPointer ptr) {
			return get(ptr.getMatchingProperty());
		}
		
		public override JsonNode get(String property) {
			JsonNode n = children.get(property);
			return n == null ? missingNode() : n;
		}
		
		public virtual override JsonNode put(String property, JsonNode value) {
			children.put(property, value);
			value.parent = this;
			value.property = property;
			return this;
		}
		
		public override JsonNode putAll(Map<String, JsonNode> properties) {
			for (String property : properties.keySet()) {
				put(property, properties.get(property));
			}
			return this;
		}
		
		public override JsonNode putAll(ObjectNode other) {
			return putAll(other.children);
		}
		
		public virtual override void setChildren(Map<String, JsonNode> children) {
			putAll(this.children = children);
		}
		
		public override JsonNode remove(String property) {
			return children.remove(property);
		}
		
		public override void removeAll(Set<String> properties) {
			for (String property : properties) {
				children.remove(property);
			}
		}
		
		public override void clear() {
			children.clear();
		}
		
		public override JsonNode putArray(String property) {
			ArrayNode n = arrayNode();
			put(property, n);
			return n;
		}
		
		public override JsonNode putObject(String property) {
			ObjectNode n = objectNode();
			put(property, n);
			return n;
		}
		
		public override JsonNode putNull(String property) {
			return put(property, nullNode());
		}
		
		public virtual override JsonNode toSObjectNode() {
			JsonNode n;
			JsonNode typeNode = get('attributes').get('type');
			if (!typeNode.isMissingNode() && RT_JsonUtil.sObjectTypeExists(typeNode.asText())) {
				n = new SObjectNode(getMap());
				n.moveTo(parent, index, property);
			}
			return n == null ? missingNode() : n;
		}
		
		public virtual override String serialize() {
			List<String> pairs = new List<String>();
			for (String k : children.keySet()) {
				pairs.add(JSON.serialize(k) + ':' + children.get(k));
			}
			return '{' + String.join(pairs, ',') + '}';
		}
	}
	
	public class SObjectNode extends ObjectNode {
		public SObject record;
		public ChildRelationship childRel;
		public Set<String> nonSchemaProperties;
		private transient Map<String, SObjectField> fieldMap;
		
		public SObjectNode() { super(); }
		public SObjectNode(Map<String, JsonNode> children) { super(children); }
		public override NodeType getNodeType() { return NodeType.SOBJECT_T; }
		public override Object value() { return record; }
		public override Id recordId() { return record.Id; }
		public override JsonNode toSObjectNode() { return this; }
		
		public override void setChildren(Map<String, JsonNode> children) {
			this.children = children;
			nonSchemaProperties = new Set<String>();
			
			SObjectType type = RT_JsonUtil.getSObjectType(get('attributes').get('type').asText());
			
			if (type != null) {
				if (fieldMap == null) {
					fieldMap = RT_JsonUtil.sObjectFieldMap(type);
				}
				JsonNode idNode = children.get('id');
				record = type.newSObject(idNode == null ? null : idNode.asText());
				
				for (String property : children.keySet()) {
					JsonNode node = children.get(property);
					put(property, node);
				}
			}
		}
		
		public override SObjectType getSObjectType() {
			SObjectType type;
			if (record != null) {
				type = record.getSObjectType();
			}
			return type;
		}
		
		
		public override JsonNode get(SObjectField field) {
			JsonNode n;
			if (field != null) {
				n = get('' + field);
			}
			return n == null ? missingNode() : n;
		}
		
		public override JsonNode put(SObjectField field, JsonNode node) {
			JsonNode n;
			if (field != null) {
				n = put('' + field, node);
			}
			return n == null ? missingNode() : n;
		}
		
		public override JsonNode put(String property, JsonNode node) {
			super.put(property, node);
			String nodeText = node.asText();
			String errorMessage;
			Boolean isRef = nodeText != null && nodeText.startsWith('{') && nodeText.endsWith('}');
			if (record == null || isRef) {
				return this;
			}
			SObjectField field = fieldMap.get(property.replaceAll('__r$','__c'));
			if (field == null) {
				nonSchemaProperties.add(property);
				return this;
			}
			DisplayType dt = RT_JsonUtil.getDisplayType(field);
			
			RecordWriter writer;
			if (node.isNull()) {
				writer = RECORD_WRITERS.get(null);
			}
			else {
				for (Set<DisplayType> dts : RECORD_WRITERS.keySet()) {
					if (dts != null && dts.contains(dt)) {
						writer = RECORD_WRITERS.get(dts);
						break;
					}
				}
			}
			if (writer != null) {
				try {
					writer.writeTo(node, record);
				}
				catch (Exception e) {
					errorMessage = e.getMessage();
				}
			}
			if (!node.isNull() && record.get(property) == null) {
				throw new JsonParsingException('The value ' + node.serialize() + ' for property ' + property + ' could not be converted to type ' + dt + ': ' + errorMessage);
			}
			return this;
		}
		
		/** Sort SObjectNodes based on their type. Used as a pre-sort in toposort.
		 */
		public override Integer compareTo(Object o) {
			Integer result = 1;
			if (o instanceof SObjectNode) {
				SObjectNode node = (SObjectNode) o;
				String stype1 = '', stype2 = '';
				if (getSObjectType() != null) {
					stype1 += getSObjectType();
				}
				if (node.getSObjectType() != null) {
					stype2 += node.getSObjectType();
				}
				result = stype1.compareTo(stype2);
			}
			return result;
		}
	}
	
	public class ArrayNode extends ContainerNode {
		public List<JsonNode> children;
		
		public ArrayNode() { children = new List<JsonNode>(); }
		public override NodeType getNodeType() { return NodeType.ARRAY_T; }
		public override JSONToken asToken() { return JSONToken.START_ARRAY; }
		public override Object value() { return children; }
		public override List<JsonNode> elements() { return children; }
		public override Integer size() { return children.size(); }
		
		public override JsonNode get(Integer index) {
			if (index >= 0 && index < children.size()) {
				return children.get(index);
			}
			return missingNode();
		}
		
		private override JsonNode atImpl(RT_JsonPointer ptr) {
			return get(ptr.getMatchingIndex());
		}
		
		public override JsonNode set(Integer index, JsonNode value) {
			if (value == null) {
				value = nullNode();
			}
			if (index == children.size()) {
				index = children.size();
				children.add(value);
			}
			else {
				children.set(index, value);
			}
			value.parent = this;
			value.index = index;
			return this;
		}
		
		public override JsonNode add(JsonNode value) {
			value.parent = this;
			value.index = children.size();
			children.add(value);
			return this;
		}
		
		public override JsonNode add(Integer index, JsonNode value) {
			if (index < 0) {
				children.add(index = 0, value);
			}
			else if (index >= children.size()) {
				index = children.size();
				children.add(value);
			}
			else {
				children.add(index, value);
			}
			value.parent = this;
			value.index = index;
			for (Integer i = index + 1; i < children.size(); i++) {
				children.get(i).index = i;
			}
			return this;
		}
		
		public override JsonNode addAll(ArrayNode other) {
			return addAll(other.children);
		}
		
		public override JsonNode addAll(List<JsonNode> nodes) {
			for (JsonNode node : nodes) {
				add(node);
			}
			return this;
		}
		
		public override JsonNode remove(Integer index) {
			if (index >= 0 && index < children.size()) {
				JsonNode n = children.remove(index);
				for (Integer i = index; i < children.size(); i++) {
					children.get(i).index = i;
				}
				return n;
			}
			return missingNode();
		}
		
		public override void clear() {
			children.clear();
		}
		
		public override JsonNode addArray() {
			ArrayNode n = arrayNode();
			add(n);
			return n;
		}
		
		public override JsonNode addObject() {
			ObjectNode n = objectNode();
			add(n);
			return n;
		}
		
		public override JsonNode addNull() {
			return add(nullNode());
		}
		
		public override JsonNode addArray(Integer index) {
			ArrayNode n = arrayNode();
			add(index, n);
			return n;
		}
		
		public override JsonNode addObject(Integer index) {
			ObjectNode n = objectNode();
			add(index, n);
			return n;
		}
		
		public override JsonNode addNull(Integer index) {
			return add(index, nullNode());
		}
		
		public override String serialize() {
			List<String> elements = new List<String>();
			for (JsonNode node : children) {
				elements.add(String.valueOf(node));
			}
			return '[' + String.join(elements, ',') + ']';
		}
	}
	
	public abstract class ValueNode extends JsonNode {
		public override Integer asInt(Integer defaultValue) { return RT_JsonUtil.toInteger(value(), defaultValue); }
		public override Long asLong(Long defaultValue) { return RT_JsonUtil.toLong(value(), defaultValue); }
		public override Double asDouble(Double defaultValue) { return RT_JsonUtil.toDouble(value(), defaultValue); }
		public override Decimal asDecimal(Decimal defaultValue) { return RT_JsonUtil.toDecimal(value(), defaultValue); }
		public override Boolean asBoolean(Boolean defaultValue) { return RT_JsonUtil.toBoolean(value(), defaultValue); }
		public override String serialize() { return JSON.serialize(value()); }
	}
	
	public class MissingNode extends ValueNode {
		public override NodeType getNodeType() { return NodeType.MISSING_T; }
		public override JSONToken asToken() { return JSONToken.NOT_AVAILABLE; }
		public override Object value() { return null; }
		public override ValueNode copy() {
			ValueNode n = missingNode();
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	public class NullNode extends ValueNode {
		public override NodeType getNodeType() { return NodeType.NULL_T; }
		public override JSONToken asToken() { return JSONToken.VALUE_NULL; }
		public override Object value() { return null; }
		public override ValueNode copy() {
			ValueNode n = nullNode();
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	public class TextNode extends ValueNode {
		public String value;
		
		public TextNode() {}
		public TextNode(String value) { this.value = value; }
		public override NodeType getNodeType() { return NodeType.STRING_T; }
		public override JSONToken asToken() { return JSONToken.VALUE_STRING; }
		public override Object value() { return value; }
		public override ValueNode copy() {
			ValueNode n = textNode(value);
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	public class BooleanNode extends ValueNode {
		public Boolean value;
		
		public BooleanNode() {}
		public BooleanNode(Boolean value) { this.value = value; }
		public override NodeType getNodeType() { return NodeType.BOOLEAN_T; }
		public override JSONToken asToken() { return value ? JSONToken.VALUE_TRUE : JSONToken.VALUE_FALSE; }
		public override Object value() { return value; }
		public override Boolean booleanValue() { return value; }
		public override ValueNode copy() {
			ValueNode n = booleanNode(value);
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	public abstract class NumericNode extends ValueNode {
		public override NodeType getNodeType() { return NodeType.NUMBER_T; }
	}
	
	public class IntNode extends NumericNode {
		public Integer value;
		
		public IntNode() {}
		public IntNode(Integer value) { this.value = value; }
		public override JSONToken asToken() { return JSONToken.VALUE_NUMBER_INT; }
		public override NumberType numberType() { return NumberType.INTEGER_T; }
		public override Object value() { return value; }
		public override ValueNode copy() {
			ValueNode n = numberNode(value);
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	public class LongNode extends NumericNode {
		public Long value;
		
		public LongNode() {}
		public LongNode(Long value) { this.value = value; }
		public override JSONToken asToken() { return JSONToken.VALUE_NUMBER_INT; }
		public override NumberType numberType() { return NumberType.LONG_T; }
		public override Object value() { return value; }
		public override ValueNode copy() {
			ValueNode n = numberNode(value);
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	public class DecimalNode extends NumericNode {
		public Decimal value;
		
		public DecimalNode() {}
		public DecimalNode(Decimal value) { this.value = value; }
		public override JSONToken asToken() { return JSONToken.VALUE_NUMBER_FLOAT; }
		public override NumberType numberType() { return NumberType.DECIMAL_T; }
		public override Object value() { return value; }
		public override ValueNode copy() {
			ValueNode n = numberNode(value);
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	public class DoubleNode extends NumericNode {
		public Double value;
		
		public DoubleNode() {}
		public DoubleNode(Double value) { this.value = value; }
		public override JSONToken asToken() { return JSONToken.VALUE_NUMBER_FLOAT; }
		public override NumberType numberType() { return NumberType.DOUBLE_T; }
		public override Object value() { return value; }
		public override ValueNode copy() {
			ValueNode n = numberNode(value);
			n.parent = parent;
			n.index = index;
			n.property = property;
			return n;
		}
	}
	
	private interface RecordWriter {
		void writeTo(JsonNode node, SObject record);
	}
	
	private class NullWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			record.put(node.property, null);
		}
	}
	
	private class StringWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			record.put(node.property, node.asText());
		}
	}
	
	private class BooleanWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			String property = node.property;
			if (node.isTextual()) {
				Boolean val = RT_JsonUtil.toBoolean(node.asText(), null);
				if (val != null) {
					record.put(property, val);
				}
			}
			else if (node.isBoolean()) {
				record.put(property, node.asBoolean());
			}
		}
	}
	
	private class IdWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			String property = node.property;
			if (node.isTextual()) {
				Id val = Id.valueOf(node.asText());
				record.put(property, val);
			}
		}
	}
	
	private class IntegerWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			String property = node.property;
			if (node.isTextual()) {
				Integer val = RT_JsonUtil.toInteger(node.asText(), null);
				if (val != null) {
					record.put(property, val);
				}
			}
			else if (node.isNumber()) {
				record.put(property, node.intValue());
			}
		}
	}
	
	private class DoubleWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			String property = node.property;
			if (node.isTextual()) {
				Decimal val = RT_JsonUtil.toDecimal(node.asText(), null);
				if (val != null) {
					record.put(property, val);
				}
			}
			else if (node.isNumber()) {
				record.put(property, node.decimalValue());
			}
		}
	}
	
	private class DateWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			String property = node.property;
			if (node.isTextual()) {
				Date val = RT_JsonUtil.toDate(node.asText());
				record.put(property, val);
			}
		}
	}
	
	private class DateTimeWriter implements RecordWriter {
		public void writeTo(JsonNode node, SObject record) {
			String property = node.property;
			if (node.isTextual()) {
				DateTime val = RT_JsonUtil.toDateTime(node.asText());
				record.put(property, val);
			}
		}
	}
	
	public class TokenReaders {
	
		Map<JSONToken, TokenReader> readers;
		
		public TokenReaders() {
			readers = new Map<JSONToken, TokenReader>();
		}
		
		public void register(JSONToken tk, TokenReader reader) {
			readers.put(tk, reader);
		}
		
		public JsonNode readAll(JSONParser parser) {
			JsonNode node;
			JSONToken tk;
			while ((tk = parser.nextToken()) != null) {
				TokenReader reader = readers.get(tk);
				if (reader != null) {
					JsonNode next = reader.read(parser, node);
					if (next != null && next.isContainerNode()) {
						node = next;
					}
				}
			}
			return node;
		}
	}
	
	public abstract class TokenReader {
	
		public abstract JsonNode create(JSONParser parser, JsonNode node);
		
		public JsonNode read(JSONParser parser, JsonNode node) {
			// Create the node for the current token; returns node.parent if at END token
			JsonNode next = create(parser, node);
			
			// Put the created node on the parent
			if (node != null && next !== node.parent) { // *NOPAD*
				if (node.isObject()) {
					node.put(parser.getCurrentName(), next);
				}
				else if (node.isArray()) {
					node.add(next);
				}
			}
			return next;
		}
	}
	
	public class StringReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return textNode(parser.getText());
		}
	}
	
	public class NullReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return nullNode();
		}
	}
	
	public class IntReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return numberNode(parser.getLongValue());
		}
	}
	
	public class FloatReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return numberNode(parser.getDecimalValue());
		}
	}
	
	public class BooleanReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return booleanNode(parser.getBooleanValue());
		}
	}
	
	public class ObjectStartReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return objectNode();
		}
	}
	
	public class ArrayStartReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return arrayNode();
		}
	}
	
	public class ContainerEndReader extends TokenReader {
		public override JsonNode create(JSONParser parser, JsonNode node) {
			return node.parent;
		}
	}
	
	public enum NodeType {
		ARRAY_T, BOOLEAN_T, MISSING_T, NULL_T, NUMBER_T, OBJECT_T, SOBJECT_T, STRING_T
	}
	
	public enum NumberType {
		INTEGER_T, LONG_T, DOUBLE_T, DECIMAL_T
	}
	
	public class JsonParsingException extends Exception {}
	
	public class NullPointerException extends Exception {}
}