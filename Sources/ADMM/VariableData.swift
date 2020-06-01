struct VariableData {
    let initValue: Double
    let initWeight: MessageWeight
    
    var initInfo: WeightedValue {
        return (value: initValue, weight: initWeight)
    }
    
    var value: Double
    
    var edges = ContiguousArray<Int>()
    var enabledEdges = ContiguousArray<Int>()
    var enabledNeedsUpdate = false
    
    //
    
    init(initValue: Double, initWeight: MessageWeight) {
        self.initValue = initValue
        self.initWeight = initWeight
        
        value = initValue
    }
    
    //
    
    mutating func addEdge(edgeIndex: Int) {
        edges.append(edgeIndex)
        enabledEdges.append(edgeIndex)
        
        enabledNeedsUpdate = true
    }
    
    mutating func reset() {
        enabledEdges = edges
        enabledNeedsUpdate = false
        
        value = initValue
    }
    
    mutating func addEnabledEdge(edgeIndex: Int) {
        enabledEdges.append(edgeIndex)
    }
    
    mutating func forceEnabledEdgesUpdate() {
        enabledNeedsUpdate = true
    }
    
    mutating func updateEnabledEdges(newEnabled: ContiguousArray<Int>) {
        enabledEdges = newEnabled
        enabledNeedsUpdate = false
    }
    
    mutating func updateValue(newValue: Double) {
        value = newValue
    }
}
