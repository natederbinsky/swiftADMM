/// A pair that has an arbitrary value and weight
public typealias WeightedValue = (value: Double, weight: MessageWeight)

/// Method of providing read-write access to a weighted value
public struct WeightedValueExchange {
    /// Associated edge-data index
    let edgeIndex: Int
    
    /// Store of the weighted value
    private var wv: WeightedValue = (value: 0.0, weight: .std)
    
    //
    
    /// Create the store
    ///
    /// - Parameter index: index of the associated edge data
    init(_ index: Int) {
        edgeIndex = index
    }
    
    /// Gets the current value of the store
    ///
    /// - returns: current weighted value
    public func get() -> WeightedValue {
        return wv
    }
    
    /// Sets the current value in the store
    ///
    /// - Parameter wv: new weighted value
    public mutating func set(_ wv: WeightedValue) {
        self.wv = wv
    }
}
