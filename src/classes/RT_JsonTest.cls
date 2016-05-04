@isTest
private class RT_JsonTest {

	static final RT_Assert Assert = RT_Assert.INSTANCE;
	static final RT_JsonMapper MAPPER = new RT_JsonMapper();
	
	static final Map<JSONToken, RT_Json.NodeType> TOKEN_NODE_MAP = new Map<JSONToken, RT_Json.NodeType> {
		JSONToken.START_OBJECT => RT_Json.NodeType.OBJECT_T,
		JSONToken.START_ARRAY => RT_Json.NodeType.ARRAY_T,
		JSONToken.NOT_AVAILABLE => RT_Json.NodeType.MISSING_T,
		JSONToken.VALUE_NULL => RT_Json.NodeType.NULL_T,
		JSONToken.VALUE_STRING => RT_Json.NodeType.STRING_T,
		JSONToken.VALUE_TRUE => RT_Json.NodeType.BOOLEAN_T,
		JSONToken.VALUE_FALSE => RT_Json.NodeType.BOOLEAN_T,
		JSONToken.VALUE_NUMBER_INT => RT_Json.NodeType.NUMBER_T,
		JSONToken.VALUE_NUMBER_FLOAT => RT_Json.NodeType.NUMBER_T
	};
	
	static final Set<RT_Json.NodeType> VALUE_TYPES = new Set<RT_Json.NodeType> {
		RT_Json.NodeType.NULL_T,
		RT_Json.NodeType.STRING_T,
		RT_Json.NodeType.BOOLEAN_T,
		RT_Json.NodeType.NUMBER_T
	};
	
	static void assertNodeTypes(RT_Json.JsonNode node, JSONToken token) {
		assertNodeTypes(node, token, null);
	}
	
	static void assertNodeTypes(RT_Json.JsonNode node, JSONToken token, RT_Json.NumberType numberType) {
		RT_Json.NodeType nodeType = TOKEN_NODE_MAP.get(token);
		
		Assert.assertEquals(token, node.asToken());
		Assert.assertEquals(nodeType, node.getNodeType());
		Assert.assertEquals(numberType, node.numberType());
		
		Assert.assertEquals(VALUE_TYPES.contains(TOKEN_NODE_MAP.get(token)), node.isValueNode());
		
		Boolean isContainerNode = nodeType == RT_Json.NodeType.OBJECT_T || nodeType == RT_Json.NodeType.SOBJECT_T || nodeType == RT_Json.NodeType.ARRAY_T;
		Assert.assertEquals(isContainerNode, node.isContainerNode());
		
		Assert.assertEquals(nodeType == RT_Json.NodeType.MISSING_T, node.isMissingNode());
		Assert.assertEquals(nodeType == RT_Json.NodeType.ARRAY_T, node.isArray());
		Assert.assertEquals(nodeType == RT_Json.NodeType.OBJECT_T, node.isObject());
		Assert.assertEquals(nodeType == RT_Json.NodeType.SOBJECT_T, node.isSObject());
		Assert.assertEquals(nodeType == RT_Json.NodeType.STRING_T, node.isTextual());
		Assert.assertEquals(nodeType == RT_Json.NodeType.BOOLEAN_T, node.isBoolean());
		Assert.assertEquals(nodeType == RT_Json.NodeType.NULL_T, node.isNull());
		Assert.assertEquals(nodeType == RT_Json.NodeType.NUMBER_T, node.isNumber());
		
		Assert.assertEquals(token == JSONToken.VALUE_NUMBER_INT, node.isIntegralNumber());
		Assert.assertEquals(numberType == RT_Json.NumberType.LONG_T, node.isLong());
		Assert.assertEquals(numberType == RT_Json.NumberType.INTEGER_T, node.isInt());
		
		Assert.assertEquals(token == JSONToken.VALUE_NUMBER_FLOAT, node.isFloatingPointNumber());
		Assert.assertEquals(numberType == RT_Json.NumberType.DECIMAL_T, node.isDecimal());
		Assert.assertEquals(numberType == RT_Json.NumberType.DOUBLE_T, node.isDouble());
	}
	
	@isTest static void testSimpleObject() {
		RT_Json.JsonNode root = MAPPER.readTree('{"attributes":{"ref_id":"test_ref"}}');
		System.debug(root.parent);
		System.debug(root);
		root.put('a', 1);
		root.put('b', true);
		root.put('c', 'cat');
		RT_Json.JsonNode d_node = root.putObject('d');
		RT_Json.JsonNode e_node = d_node.putArray('e');
		e_node.add(1.2);
		d_node.put('f', RT_Json.nullNode());
		d_node.put('g', (Long) RT_JsonUtil.MAX_INTEGER + 1L);
		d_node.put('h', false);
		d_node.put('i', Double.valueOf(3.100));
		d_node.put('j', 3.1);
		
		System.debug(root.parent);
		System.debug(root);
		System.debug(d_node.parent);
		System.debug(d_node);
		System.debug(e_node.parent);
		System.debug(e_node);
		
		// Ancestors
		Assert.assertEquals(2, e_node.depth());
		Assert.assertEquals(1, d_node.depth());
		Assert.assertEquals(0, root.depth());
		
		Assert.assertSame(e_node, e_node.ancestor(-1));
		Assert.assertSame(e_node, e_node.ancestor(0));
		Assert.assertSame(d_node, e_node.ancestor(1));
		Assert.assertSame(root, e_node.ancestor(2));
		Assert.assertTrue(e_node.ancestor(3).isMissingNode());
		
		// ObjectNode
		assertNodeTypes(root, JSONToken.START_OBJECT);
		Assert.assertEquals(5, root.size());
		Assert.assertTrue(root.get('attributes').isObject());
		Assert.assertTrue(root.get('attributes').get('ref_id').isTextual());
		Assert.assertEquals('test_ref', root.getRefId());
		Assert.assertTrue(root.eq(root.getMap()));
		Assert.assertEquals(0, root.asInt());
		Assert.assertEquals(0L, root.asLong());
		Assert.assertEquals(0.0, root.asDouble());
		Assert.assertEquals(0.0, root.asDecimal());
		Assert.assertFalse(root.asBoolean());
		Assert.assertTrue(root.copy().isNull());
		
		// MissingNode
		Assert.assertFalse(root.has('foo'));
		RT_Json.JsonNode foo = root.get('foo');
		assertNodeTypes(foo, JSONToken.NOT_AVAILABLE);
		Assert.assertTrue(foo.eq(null));
		Assert.assertNull(foo.value());
		Assert.assertFalse(foo.equals(null));
		Assert.assertEquals(foo, foo.copy());
		Assert.assertNotSame(foo, foo.copy());
		Assert.assertEquals(foo.hashCode(), foo.copy().hashCode());
		Assert.assertNull(foo.getRefId());
		Assert.assertEquals(RT_Json.NO_FIELDS, foo.getMap());
		Assert.assertTrue(foo.properties().isEmpty());
		foo.addRef('foo', 'bar');
		Assert.assertEquals(0, foo.getRefs().size());
		Assert.assertTrue(foo.put('foo', RT_Json.nullNode()).isMissingNode());
		Assert.assertTrue(foo.putArray('foo').isMissingNode());
		Assert.assertTrue(foo.putObject('foo').isMissingNode());
		Assert.assertTrue(foo.putNull('foo').isMissingNode());
		Assert.assertTrue(foo.putAll(new Map<String, RT_Json.JsonNode>()).isMissingNode());
		Assert.assertTrue(foo.putAll(RT_Json.objectNode()).isMissingNode());
		Assert.assertTrue(foo.remove('foo').isMissingNode());
		foo.removeAll(new Set<String>());
		foo.setChildren(new Map<String, RT_Json.JsonNode>());
		Assert.assertEquals(0, foo.size());
		foo.clear();
		Assert.assertFalse(foo.booleanValue());
		Assert.assertTrue(foo.get(0).isMissingNode());
		Assert.assertTrue(foo.set(0, RT_Json.nullNode()).isMissingNode());
		Assert.assertTrue(foo.add(RT_Json.nullNode()).isMissingNode());
		Assert.assertTrue(foo.add(0, RT_Json.nullNode()).isMissingNode());
		Assert.assertTrue(foo.addArray().isMissingNode());
		Assert.assertTrue(foo.addObject().isMissingNode());
		Assert.assertTrue(foo.addNull().isMissingNode());
		Assert.assertTrue(foo.addArray(0).isMissingNode());
		Assert.assertTrue(foo.addObject(0).isMissingNode());
		Assert.assertTrue(foo.addNull(0).isMissingNode());
		Assert.assertTrue(foo.addAll(RT_Json.arrayNode()).isMissingNode());
		Assert.assertTrue(foo.addAll(new List<RT_Json.JsonNode>()).isMissingNode());
		Assert.assertTrue(foo.remove(0).isMissingNode());
		
		// IntegerNode
		Assert.assertTrue(root.has('a'));
		RT_Json.JsonNode a_node = root.get('a');
		assertNodeTypes(a_node, JSONToken.VALUE_NUMBER_INT, RT_Json.NumberType.INTEGER_T);
		Assert.assertTrue(a_node.eq(a_node.value()));
		Assert.assertEquals(1, a_node.value());
		Assert.assertEquals(1, a_node.intValue());
		Assert.assertEquals(1L, a_node.longValue());
		Assert.assertEquals(1.0, a_node.decimalValue());
		Assert.assertEquals(1.0, a_node.doubleValue());
		Assert.assertEquals(a_node, a_node.copy());
		Assert.assertNotSame(a_node, a_node.copy());
		
		// TrueNode
		Assert.assertTrue(root.has('b'));
		RT_Json.JsonNode b_node = root.get('b');
		assertNodeTypes(b_node, JSONToken.VALUE_TRUE);
		Assert.assertTrue(b_node.eq(b_node.value()));
		Assert.assertTrue(b_node.value());
		Assert.assertTrue(b_node.booleanValue());
		Assert.assertEquals(b_node, b_node.copy());
		Assert.assertNotSame(b_node, b_node.copy());
		
		// TextNode
		Assert.assertTrue(root.has('c'));
		RT_Json.JsonNode c_node = root.get('c');
		assertNodeTypes(c_node, JSONToken.VALUE_STRING);
		Assert.assertTrue(c_node.eq(c_node.value()));
		Assert.assertEquals('cat', c_node.value());
		Assert.assertEquals(c_node, c_node.copy());
		Assert.assertNotSame(c_node, c_node.copy());
		
		// ObjectNode
		assertNodeTypes(d_node, JSONToken.START_OBJECT);
		Assert.assertEquals(6, d_node.size());
		Assert.assertTrue(d_node.copy().isNull());
		
		// ArrayNode
		assertNodeTypes(e_node, JSONToken.START_ARRAY);
		Assert.assertEquals(1, e_node.size());
		Assert.assertTrue(e_node.copy().isNull());
		
		// DecimalNode
		Assert.assertTrue(e_node.has(0));
		RT_Json.JsonNode e1_node = e_node.get(0);
		assertNodeTypes(e1_node, JSONToken.VALUE_NUMBER_FLOAT, RT_Json.NumberType.DECIMAL_T);
		Assert.assertTrue(e1_node.eq(e1_node.value()));
		Assert.assertEquals(1.2, e1_node.value());
		Assert.assertEquals(1, e1_node.intValue());
		Assert.assertEquals(1L, e1_node.longValue());
		Assert.assertEquals(1.2, e1_node.decimalValue());
		Assert.assertEquals(1.2, e1_node.doubleValue());
		Assert.assertEquals(e1_node, e1_node.copy());
		Assert.assertNotSame(e1_node, e1_node.copy());
		
		// NullNode
		Assert.assertTrue(d_node.has('f'));
		RT_Json.JsonNode f_node = d_node.get('f');
		assertNodeTypes(f_node, JSONToken.VALUE_NULL);
		Assert.assertTrue(f_node.eq(f_node.value()));
		Assert.assertNull(f_node.value());
		Assert.assertFalse(f_node.equals(null));
		Assert.assertEquals(f_node, f_node.copy());
		Assert.assertNotSame(f_node, f_node.copy());
		
		// LongNode
		Assert.assertTrue(d_node.has('g'));
		RT_Json.JsonNode g_node = d_node.get('g');
		assertNodeTypes(g_node, JSONToken.VALUE_NUMBER_INT, RT_Json.NumberType.LONG_T);
		Assert.assertTrue(g_node.eq(g_node.value()));
		Assert.assertEquals((Long) RT_JsonUtil.MAX_INTEGER + 1L, g_node.value());
		Assert.assertEquals(RT_JsonUtil.MAX_INTEGER, g_node.intValue());
		Assert.assertEquals((Long) RT_JsonUtil.MAX_INTEGER + 1L, g_node.longValue());
		Assert.assertEquals(Decimal.valueOf(RT_JsonUtil.MAX_INTEGER) + 1.0, g_node.decimalValue());
		Assert.assertEquals(Decimal.valueOf(RT_JsonUtil.MAX_INTEGER) + 1.0, g_node.doubleValue());
		Assert.assertEquals(g_node, g_node.copy());
		Assert.assertNotSame(g_node, g_node.copy());
		
		// FalseNode
		Assert.assertTrue(d_node.has('h'));
		RT_Json.JsonNode h_node = d_node.get('h');
		assertNodeTypes(h_node, JSONToken.VALUE_FALSE);
		Assert.assertTrue(h_node.eq(h_node.value()));
		Assert.assertFalse(h_node.value());
		Assert.assertFalse(h_node.booleanValue());
		Assert.assertEquals(h_node, h_node.copy());
		Assert.assertNotSame(h_node, h_node.copy());
		
		// DecimalNode
		Assert.assertTrue(d_node.has('i'));
		RT_Json.JsonNode i_node = d_node.get('i');
		assertNodeTypes(i_node, JSONToken.VALUE_NUMBER_FLOAT, RT_Json.NumberType.DOUBLE_T);
		Assert.assertTrue(i_node.eq(i_node.value()));
		Assert.assertEquals(3.100, i_node.value());
		Assert.assertEquals(3, i_node.intValue());
		Assert.assertEquals(3L, i_node.longValue());
		Assert.assertEquals(3.100, i_node.decimalValue());
		Assert.assertEquals(3.100, i_node.doubleValue());
		Assert.assertEquals(i_node, i_node.copy());
		Assert.assertNotSame(i_node, i_node.copy());
	}
	
	@isTest static void testConversions() {
		RT_Json.JsonNode n;
		
		n = MAPPER.readTree('{"a":1}').get('a');
		System.debug(n);
		Assert.assertEquals('1', n.asText());
		Assert.assertEquals(1, n.asInt());
		Assert.assertEquals(1L, n.asLong());
		Assert.assertEquals(1.0, n.asDecimal());
		Assert.assertEquals(1.0, n.asDouble());
		Assert.assertFalse(n.asBoolean());
		
		n = MAPPER.readTree('{"a":1.0}').get('a');
		Assert.assertEquals('1.0', n.asText());
		Assert.assertEquals(1, n.asInt());
		Assert.assertEquals(1L, n.asLong());
		Assert.assertEquals(1.0, n.asDecimal());
		Assert.assertEquals(1.0, n.asDouble());
		Assert.assertFalse(n.asBoolean());
		
		n = MAPPER.readTree('{"a":true}').get('a');
		Assert.assertEquals('true', n.asText());
		Assert.assertEquals(1, n.asInt());
		Assert.assertEquals(1L, n.asLong());
		Assert.assertEquals(1.0, n.asDecimal());
		Assert.assertEquals(1.0, n.asDouble());
		Assert.assertTrue(n.asBoolean());
		
		n = MAPPER.readTree('{"a":false}').get('a');
		Assert.assertEquals('false', n.asText());
		Assert.assertEquals(0, n.asInt());
		Assert.assertEquals(0L, n.asLong());
		Assert.assertEquals(0.0, n.asDecimal());
		Assert.assertEquals(0.0, n.asDouble());
		Assert.assertFalse(n.asBoolean());
	}
	
	@isTest static void testObjectOperations() {
		RT_Json.JsonNode n = new RT_Json.ObjectNode();
		Assert.assertEquals(0, n.size());
		n.addRef('foo', 'bar');
		Assert.assertEquals(1, n.getRefs().size());
		n.putNull('a');
		n.putArray('b');
		n.putObject('c');
		
		RT_Json.JsonNode m = new RT_Json.ObjectNode();
		m.putAll(n.getMap());
		Assert.assertEquals(3, m.size());
		Assert.assertTrue(m.remove('a').isNull());
		m.removeAll(new Set<String> {'a', 'b'});
		Assert.assertEquals(1, m.size());
		m.clear();
		Assert.assertEquals(0, m.size());
		
		Assert.assertEquals(3, n.size());
		m.putAll((RT_Json.ObjectNode) n);
		Assert.assertEquals(3, m.size());
		
		m.put('d', Double.valueOf(42));
		m.put('e', RT_Json.numberNode(1));
		
		// cover some invalid method calls
		Assert.assertNull(n.getSObjectType());
		Assert.assertNull(n.recordId());
	}
	
	@isTest static void testSObjectOperations() {
		String birthdate = Date.newInstance(1987, 5, 29).format();
		Map<String, Object> tree = new Map<String, Object> {
			'foo' => 'bar',
			'records' => new List<Object> {
				new Map<String, Object> {
					'attributes' => new Map<String, Object> {
						'type' => 'foo__Account'
					},
					'foo__Website' => 'http://www.redteal.com',
					'AccountSource' => 'Direct Outreach',
					'NumberOfEmployees' => 10,
					'AnnualRevenue' => 10000000.0,
					'Type' => 'Partner',
					'foo__Phone' => '(888) 555-7890',
					'Fax' => null,
					'Description' => 5.100,
					'Contacts' => new Map<String, Object> {
						'records' => new List<Object> {
							new Map<String, Object> {
								'attributes' => new Map<String, Object> {
									'ref_id' => 'dave'
								},
								'FirstName' => 'Dave',
								'foo__LastName' => 'Meagher',
								'DoNotCall' => 'true',
								'Description' => true
							},
							new Map<String, Object> {
								'FirstName' => 'Jon',
								'foo__LastName' => 'Crenshaw',
								'ReportsToId' => '{dave.Id}',
								'DoNotCall' => true,
								'Birthdate' => birthdate,
								'Description' => '42'
							}
						}
					}
				},
				new Map<String, Object> {
					'attributes' => new Map<String, Object> {
						'type' => 'foo__Account'
					},
					'Name' => 'Pacific Gas and Electric',
					'foo__Website' => 'http://www.pge.com',
					'NumberOfEmployees' => '22581',
					'AnnualRevenue' => '17100000000.0',
					'foo__Phone' => '(888) 555-7890'
				},
				new Map<String, Object> {
					'attributes' => new Map<String, Object> {
						'type' => 'foo__Account'
					},
					'Name' => 'EcoAct',
					'foo__Website' => 'http://www.ecoact.org',
					'NumberOfEmployees' => '500',
					'AnnualRevenue' => '100000000.0',
					'foo__Phone' => '(888) 555-7890'
				}
			}
		};
		MAPPER.conf.overrides.addOverride('foo__Account', Account.sObjectType);
		MAPPER.conf.overrides.addOverride('Contact', 'foo__Description', Contact.Description);
		MAPPER.conf.overrides.addOverride('Contact', 'foo__LastName', Contact.LastName);
		MAPPER.conf.overrides.addOverride('foo__Account', 'foo__Website', Account.Website);
		MAPPER.conf.overrides.addOverride('foo__Account', 'foo__Phone', Account.Phone);
		MAPPER.conf.overrides.addExclusion('foo__Account', 'Type');
		MAPPER.conf.overrides.addExclusion('foo__Account', 'Foo');
		
		MAPPER.parse(JSON.serialize(tree));
		Assert.assertTrue(MAPPER.hasErrors); // no account name
		MAPPER.reset();
		
		((Map<String, Object>)((List<Object>) tree.get('records')).get(0)).put('Name', 'RedTeal');
		
		RT_Json.JsonNode root = MAPPER.readTree(JSON.serialize(tree));
		Assert.assertTrue(root.at('/foo').toSObjectNode().isMissingNode());
		RT_Json.JsonNode n = root.at('/records/0');
		Assert.assertEquals(RT_Json.NodeType.SOBJECT_T, n.getNodeType());
		Assert.assertTrue(n.isSObject());
		Assert.assertSame(n, n.toSObjectNode());
		Assert.assertEquals(Account.sObjectType, n.getSObjectType());
		
		MAPPER.reset();
		Map<Id, SObject> records = MAPPER.parse(JSON.serialize(tree));
		Assert.assertEquals(5, records.size());
		Id daveId, jonId;
		for (Id id : records.keySet()) {
			SObject record = records.get(id);
			if (record instanceof Contact) {
				String name = (String) record.get('FirstName');
				if (name == 'Dave') {
					daveId = id;
				}
				else if (name == 'Jon') {
					jonId = id;
				}
			}
		}
		for (Id id : records.keySet()) {
			SObject record = records.get(id);
			if (record.getSObjectType() == Contact.sObjectType) {
				Assert.assertNotNull(record.get('AccountId'));
				if (record.Id == jonId) {
					Assert.assertEquals(daveId, record.get('ReportsToId'));
				}
				System.debug(record.get('AccountId'));
			}
			else if (record.getSObjectType() == Account.sObjectType) {
				Assert.assertNotNull(record.get('Website')); // override
				Assert.assertNotNull(record.get('Phone')); // override
				Assert.assertNull(record.get('Type')); // excluded
			}
		}
	}
	
	@isTest static void testArrayOperations() {
		RT_Json.JsonNode n = MAPPER.readTree('[]');
		Assert.assertTrue(n.isArray());
		Assert.assertEquals(0, n.size());
		Assert.assertSame(n, n.add(1));
		Assert.assertEquals(1, n.size());
		Assert.assertSame(n, n.add(2L));
		Assert.assertEquals(2, n.size());
		Assert.assertSame(n, n.add(Double.valueOf(3.1)));
		Assert.assertEquals(3, n.size());
		Assert.assertSame(n, n.add(3.2));
		Assert.assertEquals(4, n.size());
		Assert.assertSame(n, n.add('foo'));
		Assert.assertEquals(5, n.size());
		Assert.assertSame(n, n.add(true));
		Assert.assertEquals(6, n.size());
		Assert.assertTrue(n.get(5).value());
		Assert.assertEquals('foo', n.get(4).value());
		Assert.assertSame(n, n.set(4, RT_Json.textNode('bar')));
		Assert.assertEquals(6, n.size());
		Assert.assertTrue(n.get(4).eq('bar'));
		try {
			n.set(10, RT_Json.textNode('oops!'));
			Assert.fail();
		}
		catch (Exception e) {}
		Assert.assertTrue(n.get(10).isMissingNode());
		Assert.assertTrue(n.addArray().isArray());
		Assert.assertEquals(7, n.size());
		Assert.assertSame(n, n.addNull());
		Assert.assertEquals(8, n.size());
		Assert.assertSame(n, n.set(7, null));
		Assert.assertEquals(8, n.size());
		Assert.assertNull(n.get(7).value());
		Assert.assertSame(n, n.add(-1, RT_Json.textNode('foo'))); // should add at 0 index
		Assert.assertEquals(9, n.size());
		Assert.assertSame(n, n.add(11, RT_Json.falseNode())); // should add at last index
		Assert.assertEquals(10, n.size());
		
		RT_Json.JsonNode arr = RT_Json.arrayNode();
		Assert.assertSame(arr, arr.addAll((RT_Json.ArrayNode) n));
		Assert.assertEquals(10, arr.size());
		Assert.assertTrue(arr.remove(11).isMissingNode());
		Assert.assertEquals('foo', arr.remove(0).value());
		Assert.assertEquals(10, n.size());
		Assert.assertEquals(9, arr.size());
		arr.clear();
		Assert.assertNotSame(arr, arr.addObject());
		Assert.assertNotSame(arr, arr.addObject(0));
		Assert.assertNotSame(arr, arr.addArray(0));
		Assert.assertSame(arr, arr.addNull(0));
		Assert.assertEquals(4, arr.size());
	}
	
	@isTest static void testAsList() {
		RT_Json.JsonNode n = MAPPER.readTree('{"a":1,"b":2,"c":true,"d":{},"e":[]}');
		Assert.assertEquals(5, RT_Json.asList(n.elements(), null).size());
		Assert.assertEquals(2, RT_Json.asList(n.elements(), RT_Json.NodeType.NUMBER_T).size());
		Assert.assertEquals(1, RT_Json.asList(n.elements(), RT_Json.NodeType.ARRAY_T).size());
		Assert.assertEquals(1, RT_Json.asList(n.elements(), RT_Json.NodeType.OBJECT_T).size());
		Assert.assertEquals(1, RT_Json.asList(n.elements(), RT_Json.NodeType.BOOLEAN_T).size());
	}
	
	@isTest static void testPointers() {
		RT_Json.JsonNode n = MAPPER.readTree('{"a":[1,2,3],"b":{"c":{"d":[1,2,3]}}}');
		Assert.assertEquals(3, n.at('/a/2').value());
		Assert.assertEquals('d', n.at('/b/c/d').property);
		Assert.assertEquals(3, n.at('/b/c/d').size());
		Assert.assertEquals(2, n.at('/b/c/d/1').value());
		Assert.assertTrue(RT_Json.nullNode().at('/foo').isMissingNode());
	}
}