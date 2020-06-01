public typealias MinimizationFunction = (UnsafeMutableBufferPointer<WeightedValueExchange>) -> Void

struct FactorData {
    let f: MinimizationFunction
    var edges: ContiguousArray<WeightedValueExchange>
    
    var enabled: Bool
    
    //
    
    init(edges: [Int], f: @escaping MinimizationFunction) {
        self.f = f
        self.edges = ContiguousArray<WeightedValueExchange>(edges.map { WeightedValueExchange( $0 ) })
        
        self.enabled = true
    }
    
    //
    
    mutating func _switch(_ newVal: Bool) -> Bool {
        if enabled != newVal {
            enabled = newVal
            
            return true
        }
        
        return false
    }
    
    mutating func enable() -> Bool {
        return _switch(true)
    }
    
    mutating func disable() -> Bool {
        return _switch(false)
    }
    
    mutating func reset() {
        enabled = true
    }
}
