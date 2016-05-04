public class RT_DirectedGraph {

	/**
	 * Toposort sorting strategy singleton
	 */
	static final SortingStrategy TOPOSORT = new TopoSort();
	
	/**
	 * Source nodes mapped to outgoing (dest) edges. If node instances
	 * are of custom classes, overriding equals and hashCode is advised
	 */
	public final Map<Object, Set<Object>> graph;
	
	/**
	 * The reversed graph
	 */
	private Map<Object, Set<Object>> reversed;
	
	/**
	 * Construct an empty graph
	 */
	public RT_DirectedGraph() {
		graph = new Map<Object, Set<Object>>();
		reversed = new Map<Object, Set<Object>>();
	}
	
	/**
	 * Construct graph with predefined nodes/edges
	 */
	public RT_DirectedGraph(Map<Object, Set<Object>> graph) {
		this.graph = graph;
		reversed = new Map<Object, Set<Object>>();
	}
	
	/**
	 * Clear the graph
	 */
	public void clear() {
		graph.clear();
		reversed.clear();
	}

	public RT_DirectedGraph copy() {
		return new RT_DirectedGraph(graph);
	}
	
	/**
	 * @return all nodes in the graph
	 */
	public Set<Object> getNodes() {
		return graph.keySet();
	}
	
	/**
	 * @param node node to add to the graph
	 */
	public void addNode(Object node) {
		// If the node already exists, don't do anything
		if (!nodeExists(node)) {
			// Otherwise, add the node with an empty set of outgoing edges
			graph.put(node, new Set<Object>());
			reversed.clear();
		}
	}
	
	/**
	 * Remove a node from the graph
	 */
	public void removeNode(Object node) {
		if (nodeExists(node)) {
			for (Object source : graph.keySet()) {
				graph.get(source).remove(node);
			}
			graph.remove(node);
			reversed.clear();
		}
	}
	
	/**
	 * Given a start node, and a destination, adds an arc from the
	 * start node to the destination
	 */
	public void addEdge(Object start, Object dest) {
		if (graph.containsKey(start) && graph.containsKey(dest)) {
			graph.get(start).add(dest);
			reversed.clear();
		}
	}
	
	/**
	 * Remove edge from start (the dependency) to dest from the graph
	 */
	public void removeEdge(Object start, Object dest) {
		if (graph.containsKey(start) && graph.containsKey(dest)) {
			graph.get(start).remove(dest);
			reversed.clear();
		}
	}
	
	/**
	 * @param node
	 * @return whether the node exists in the graph
	 */
	public Boolean nodeExists(Object node) {
		return graph.containsKey(node);
	}
	
	/**
	 * @param start
	 * @param dest
	 * @return whether an edge exists from start to dest
	 */
	public Boolean edgeExists(Object start, Object dest) {
		return nodeExists(start) && graph.get(start).contains(dest);
	}
	
	/**
	 * Get the edges pointing away from a node
	 * @param start
	 * @return edges to start node, or an empty set if it does not exist
	 */
	public Set<Object> edgesFrom(Object start) {
		if (nodeExists(start)) {
			return graph.get(start).clone();
		}
		return new Set<Object>();
	}
	
	/**
	 * Get the edges pointing to a node; reversed form of graph#edgesFrom()
	 *
	 * @param node
	 * @return edges to dest node, or an empty set if it does not exist
	 */
	public Set<Object> edgesTo(Object dest) {
		return reverse().edgesFrom(dest);
	}
	
	/**
	 * @return number of nodes in the graph
	 */
	public Integer size() {
		return graph.size();
	}
	
	/**
	 * @return whether the graph is empty
	 */
	public Boolean isEmpty() {
		return graph.isEmpty();
	}
	
	/**
	 * @return the reverse of the input graph
	 */
	public RT_DirectedGraph reverse() {
		RT_DirectedGraph result = new RT_DirectedGraph(reversed);
		if (!result.isEmpty()) {
			return result;
		}
		
		// add all the nodes from the original graph
		for (Object node : graph.keySet()) {
			result.addNode(node);
		}
		
		// scan all edges in graph and add their reverse to the reverse graph
		for (Object source : graph.keySet()) {
			for (Object dest : edgesFrom(source)) {
				result.addEdge(dest, source);
			}
		}
		return result;
	}
	
	/**
	 * @return topologically sorted list of the nodes in the graph.
	 */
	public List<Object> toposort() {
		return TOPOSORT.sort(this);
	}
	
	public interface SortingStrategy {
		List<Object> sort(RT_DirectedGraph g);
	}
	
	public class TopoSort implements SortingStrategy {
		/**
		 * Given a directed acyclic graph, returns a topological sorting of the nodes
		 * in the graph. If the input graph is not a DAG, throws an IllegalArgumentException.
		 */
		public List<Object> sort(RT_DirectedGraph g) {
			// Reverse graph from the input graph.
			RT_DirectedGraph reversed = g.reverse();
			
			// Topologically sorted result
			List<Object> result = new List<Object>();
			
			// Set of visited nodes
			Set<Object> visited = new Set<Object>();
			
			/* Set of fully expanded nodes. if the graph contains a cycle, then we can
			 * detect this by noting that a node has been explored but not fully expanded.
			 */
			Set<Object> expanded = new Set<Object>();
			
			// Fire off a DFS from each node in the graph.
			for (Object node : reversed.getNodes()) {
				explore(node, reversed, result, visited, expanded);
			}
			// Hand back the resulting ordering.
			return result;
		}
		
		
		/**
		 * Recursively perform a DFS from the specified node, marking all nodes
		 * encountered by the search.
		 */
		private void explore(Object node, RT_DirectedGraph g, List<Object> ordering,
		             Set<Object> visited, Set<Object> expanded) {
			// Check whether we've been here before. If so, we should stop the search
			if (visited.contains(node)) {
				/* There are two cases to consider. First, if this node has
				 * already been expanded, then it's already been assigned a
				 * position in the final topological sort and we don't need to
				 * explore it again. However, if it hasn't been expanded, it means
				 * that we've just found a node that is currently being explored,
				 * and therefore is part of a cycle. In that case, we should
				 * report an error.
				 */
				if (expanded.contains(node)) {
					return;
				}
				throw new IllegalArgumentException('Graph contains a cycle.');
			}
			
			// Mark that we've been here
			visited.add(node);
			
			// Recursively explore all of the node's predecessors
			for (Object predecessor : g.edgesFrom(node)) {
				explore(predecessor, g, ordering, visited, expanded);
			}
			
			/* Having explored all of the node's predecessors, we
			 * can now add this node to the sorted ordering
			 */
			ordering.add(node);
			
			// Similarly, mark that this node is done being expanded
			expanded.add(node);
		}
	}
	
	public class IllegalArgumentException extends Exception {}
}