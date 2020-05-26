/// Implements the constraint that all supplied edges output
/// the same value (as dictated by supplied weights)
public class EqualValueConstraint {
    /// Edges over which to enforce equality
    private var edges = [Edge]()
    
    /// Algorithm-specific enforcement function
    private let _enforce: ([Edge]) -> Void
    
    /// Subset of edges that are currently enabled
    private var enabledEdges = [Edge]()
    
    /// Last valid value
    private var lastZ: Double
    
    // Should the enabledEdges be checked for disabled edges?
    private var clearDisabled = false
    
    /// Value output after the most recent equality enforcement
    public var value: Double {
        enabledEdges.isEmpty ? lastZ: enabledEdges[0].z
    }
    
    // *********************************************
    
    /// Create an equality constraint
    ///
    /// - Parameter twa: should non-standard weights be considered?
    /// - Parameter initialZ: initial value
    public init(twa: Bool, initialZ: Double) {
        _enforce = twa ? EqualValueConstraint._enforceTWA : EqualValueConstraint._enforceADMM
        lastZ = initialZ
    }
    
    /// Adds an edge to the constraint
    ///
    /// - Parameter edge: edge to be added for equality enforcement
    public func addEdge(_ edge: Edge) {
        edges.append(edge)
        if edge.isEnabled {
            enabledEdges.append(edge)
        }
    }
    
    public func addEnabled(_ edge: Edge) {
        enabledEdges.append(edge)
    }
    
    public func clearDisabledEdges() {
        clearDisabled = true
    }
    
    /// Enforces the equality constraint
    public func enforce() {
        if clearDisabled {
            enabledEdges = enabledEdges.filter { $0.isEnabled }
            clearDisabled = false
        }
        
        if !enabledEdges.isEmpty {
            _enforce(enabledEdges)
            lastZ = enabledEdges[0].z
        }
    }
    
    /// Resets all edges and forces edge refresh
    ///
    /// - Parameters:
    ///   - initialZ: value set for each edge
    ///   - initialWeight: message weight set for each edge
    func reset(_ initialZ: Double, _ initialWeight: ResultWeight) {
        edges.forEach { $0.reset(initialZ, initialWeight) }
        enabledEdges = edges
        clearDisabled = false
        lastZ = initialZ
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
