/// Data associated with each variable of an objective graph
struct VariableData {
    /// Initial weighted value for all edges of this variable
    let initInfo: WeightedValue
    
    /// Current value of this variable
    var value: Double
    
    /// Indexes of edge data associated with this variable
    var edges = ContiguousArray<Int>()
    
    /// Indexes of enabled edges associated with this variable
    var enabledEdges = ContiguousArray<Int>()
    
    /// Flag as to whether enabled edges should be filtered
    /// before next value enforcement
    var enabledNeedsUpdate = false
    
    //
    
    /// Create the variable
    ///
    /// - Parameter initValue: initial value for the variable
    /// - Parameter initWeight: initial weight for the variable
    init(initValue: Double, initWeight: MessageWeight) {
        self.initInfo = (value: initValue, weight: initWeight)
        
        value = initValue
    }
    
    /// Resets this variable: all edges enabled, value=initial value
    mutating func reset() {
        enabledEdges = edges
        enabledNeedsUpdate = false
        
        value = initInfo.value
    }
    
    //
    
    /// Adds a new edge to this variable
    ///
    /// - Parameter edgeIndex: index of the associated edge data
    mutating func addEdge(edgeIndex: Int) {
        edges.append(edgeIndex)
        enabledEdges.append(edgeIndex)
        
        enabledNeedsUpdate = true
    }
    
    /// Indicates that an existing edge has been enabled
    ///
    /// - parameter edgeIndex: index of the newly enabled edge
    mutating func addEnabledEdge(edgeIndex: Int) {
        enabledEdges.append(edgeIndex)
    }
    
    /// Indicate that the enabled-edge list should be updated before
    /// next value enforcement
    mutating func forceEnabledEdgesUpdate() {
        enabledNeedsUpdate = true
    }
    
    /// Updates the enabled-edge list and unflags for updating
    ///
    /// - Parameter newEnabled: new value for the enabled-edge list
    mutating func updateEnabledEdges(newEnabled: ContiguousArray<Int>) {
        enabledEdges = newEnabled
        enabledNeedsUpdate = false
    }
    
    /// Sets a new value for this variable
    ///
    /// - Parameter newValue: new variable value
    mutating func updateValue(newValue: Double) {
        value = newValue
    }
}
