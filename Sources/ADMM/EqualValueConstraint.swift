/// Implements the constraint that all supplied edges output
/// the same value (as dictated by supplied weights)
public class EqualValueConstraint {
    /// Edges over which to enforce equality
    private var edges = [Edge]()
    
    /// Algorithm-specific enforcement function
    private let _enforce: ([Edge]) -> Void
    
    /// Subset of edges that are currently enabled
    private var enabledEdges = [Edge]()
    
    /// Flag to update enabled edges before next
    /// opportunity to enforce equality
    private var needEdgeRefresh = true
    
    /// Value output after the most recent equality enforcement
    public var value: Double? {
        enabledEdges.isEmpty ? nil: enabledEdges[0].z
    }
    
    // *********************************************
    
    /// Create an equality constraint
    ///
    /// - Parameter twa: should non-standard weights be considered?
    public init(twa: Bool) {
        _enforce = twa ? EqualValueConstraint._enforceTWA : EqualValueConstraint._enforceADMM
    }
    
    /// Adds an edge to the constraint
    ///
    /// - Parameter edge: edge to be added for equality enforcement
    public func addEdge(_ edge: Edge) {
        edges.append(edge)
        needEdgeRefresh = true
    }
    
    /// Indicates that before next enforcement, the set of enabled
    /// edges should be reconsidered
    ///
    /// - Important: This happens automatically when a new edge is added
    public func forceEdgeRefresh() {
        needEdgeRefresh = true
    }
    
    /// Enforces the equality constraint
    public func enforce() {
        if needEdgeRefresh {
            enabledEdges = edges.filter { $0.isEnabled }
            needEdgeRefresh = false
        }
        
        _enforce(enabledEdges)
    }
    
    /// Resets all edges and forces edge refresh
    ///
    /// - Parameters:
    ///   - initialZ: value set for each edge
    ///   - initialWeight: message weight set for each edge
    func reset(_ initialZ: Double, _ initialWeight: ResultWeight) {
        edges.forEach { $0.reset(initialZ, initialWeight) }
        needEdgeRefresh = true
    }
    
    // *********************************************
    
    /// Computes the average value of supplied edges' messages
    ///
    /// - Parameter edgesToInclude: edges to consider in the average
    /// - Returns: average of supplied edges
    /// - Precondition: `edgesToInclude` must be non-empty
    private static func _msgAvg(_ edgesToInclude: [Edge]) -> Double {
        let sum = edgesToInclude.reduce(0) { (result, element) in
            return result + element.msg
        }
        
        return sum / Double(edgesToInclude.count)
    }
    
    /// Enforces equal output value given three-weight paradigm
    ///
    /// Cases:
    /// - No infinity: result is average of non-zero-weighted edges (or all, if all zero-weight), standard weight
    /// - One infinity (or multiple that agree): result is that, infinite weight
    /// - Multiple infinity (don't agree): crash
    ///
    /// - Parameter edges: the edges to consider
    private static func _enforceTWA(edges: [Edge]) {
        let infEdges = edges.filter { $0.weight == .inf }
        
        var newVal = 0.0
        var newWeight: ResultWeight = .std
        
        if infEdges.isEmpty {
            let nonZeroEdges = edges.filter { $0.weight != .zero }
            
            if nonZeroEdges.isEmpty {
                newVal = _msgAvg(edges)
            } else {
                newVal = _msgAvg(nonZeroEdges)
            }
        } else if infEdges.count == 1 {
            newVal = infEdges[0].msg
            newWeight = .inf
        } else {
            let agreement = infEdges[1...].reduce(Double?(infEdges[0].msg)) {
                result, edge in
                if let prevMsg = result {
                    return (prevMsg == edge.msg) ? edge.msg : nil
                } else {
                    return nil
                }
            }
            
            if let agreementVal = agreement {
                newVal = agreementVal
                newWeight = .inf
            } else {
                infEdges.forEach {
                    print($0.msg)
                }
                
                // Well since we are 100% sure of two
                // contradictory values, then...
                crash()
            }
        }
        
        for edge in edges {
            edge.setResult(newVal, weight: newWeight)
        }
    }
    
    /// Enforces equal output value given single-weight paradigm
    ///
    /// Output value is just average of incoming messages
    private static func _enforceADMM(edges: [Edge]) {
        let newZ = _msgAvg(edges)
        
        for edge in edges {
            edge.setResult(newZ)
        }
    }
}
