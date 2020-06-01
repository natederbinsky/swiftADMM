public typealias WeightedValue = (value: Double, weight: MessageWeight)

public struct WeightedValueExchange {
    let edgeIndex: Int
    
    private var wv: WeightedValue = (value: 0.0, weight: .std)
    
    //
    
    init(_ index: Int) {
        edgeIndex = index
    }
    
    public func get() -> WeightedValue {
        return wv
    }
    
    public mutating func set(_ wv: WeightedValue) {
        self.wv = wv
    }
}
