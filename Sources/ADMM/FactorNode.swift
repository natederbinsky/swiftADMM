/// Client reference to a factor in an objective graph
public struct FactorNode {
    /// Associated index of the factor in the graph
    let factorIndex: Int
    
    /// Create the factor-node reference
    ///
    /// - Parameter index: index of the factor data
    init(index: Int) {
        factorIndex = index
    }
}
