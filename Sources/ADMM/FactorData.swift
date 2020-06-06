/// Given weighted messages, minimizes a local objective
public typealias MinimizationFunction = (UnsafeMutableBufferPointer<WeightedValueExchange>) -> Void

/// Data associated with each factor of an objective graph
struct FactorData {
    /// Local minimization
    let f: MinimizationFunction
    
    /// Source/destination for values/weights read/written by the minimization function
    var edges: ContiguousArray<WeightedValueExchange>
    
    /// Is this factor active?
    var enabled: Bool
    
    //
    
    /// Create a factor in the objective graph, given associated edge indexes
    ///
    /// - Parameter edges: indexes of existing graph edges (in order to associate weighted-value exchange)
    /// - Parameter f: local minimization function
    init(edges: [Int], f: @escaping MinimizationFunction) {
        self.f = f
        self.edges = ContiguousArray<WeightedValueExchange>(edges.map { WeightedValueExchange( $0 ) })
        
        self.enabled = true
    }
    
    /// Sets the factor to active
    mutating func reset() {
        enabled = true
    }
    
    //
    
    /// Sets the enabled flag to provided value, returning if a change was made
    ///
    /// - Parameter newVal: intended enabled state
    /// - Returns: was enabled state changed by this call?
    mutating private func _switch(_ newVal: Bool) -> Bool {
        if enabled != newVal {
            enabled = newVal
            
            return true
        }
        
        return false
    }
    
    /// Enable this factor
    ///
    /// - Returns: was the state of the factor changed by this call?
    mutating func enable() -> Bool {
        return _switch(true)
    }
    
    /// Disable this factor
    ///
    /// - Returns: was the state of the factor changed by this call?
    mutating func disable() -> Bool {
        return _switch(false)
    }
}
