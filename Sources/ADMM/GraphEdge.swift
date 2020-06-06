/// Client reference to an edge in an objective graph
public struct GraphEdge {
    /// Associated index of the edge in the graph
    let edgeIndex: Int
    
    /// Create the edge reference
    ///
    /// - Parameter index: index of the edge data
    init(index: Int) {
        self.edgeIndex = index
    }
}
