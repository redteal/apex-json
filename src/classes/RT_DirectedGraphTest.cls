@isTest class RT_DirectedGraphTest {

	static final RT_Assert Assert = RT_Assert.INSTANCE;
	
	@isTest static void test() {
		RT_DirectedGraph graph = new RT_DirectedGraph();
		
		graph.addNode(1);
		graph.addNode(2);
		graph.addNode(3);
		graph.addNode(4);
		graph.addNode(5);
		
		Assert.assertEquals(5, graph.size());
		
		Assert.assertTrue(graph.nodeExists(1));
		Assert.assertTrue(graph.nodeExists(2));
		Assert.assertTrue(graph.nodeExists(3));
		Assert.assertTrue(graph.nodeExists(4));
		Assert.assertTrue(graph.nodeExists(5));
		
		graph.addEdge(2, 3);
		graph.addEdge(3, 4);
		graph.addEdge(1, 4);
		graph.addEdge(1, 3);
		graph.addEdge(5, 1);

		graph.removeNode(5);
		Assert.assertEquals(4, graph.size());
		Assert.assertFalse(graph.nodeExists(5));
		Assert.assertFalse(graph.edgeExists(5, 1));
		
		RT_DirectedGraph reversed = graph.reverse();
		Assert.assertEquals(4, reversed.size());
		Assert.assertTrue(reversed.edgeExists(3, 2));
		Assert.assertTrue(reversed.edgeExists(4, 3));
		Assert.assertTrue(reversed.edgeExists(4, 1));
		Assert.assertTrue(reversed.edgeExists(3, 1));
		
		Assert.assertTrue(graph.edgeExists(2, 3));
		Assert.assertFalse(graph.edgeExists(1, 2));
		
		Assert.assertEquals(2, graph.edgesFrom(1).size());
		Assert.assertEquals(1, graph.edgesFrom(2).size());
		Assert.assertEquals(1, graph.edgesFrom(3).size());
		Assert.assertEquals(0, graph.edgesFrom(4).size());

		Assert.assertEquals(0, graph.edgesTo(1).size());
		Assert.assertEquals(0, graph.edgesTo(2).size());
		Assert.assertEquals(2, graph.edgesTo(3).size());
		Assert.assertEquals(2, graph.edgesTo(4).size());
		
		graph.addNode(5);
		Assert.assertTrue(graph.edgesFrom(6).isEmpty());
		
		graph.removeEdge(1, 6);
		
		graph.addEdge(4, 2);
		try {
			graph.toposort();
			Assert.fail();
		}
		catch (RT_DirectedGraph.IllegalArgumentException e) {}
		
		graph.removeEdge(4, 2);
		
		Assert.assertEquals(5, graph.toposort().size());
		
		graph.clear();
		Assert.assertTrue(graph.isEmpty());
	}
}