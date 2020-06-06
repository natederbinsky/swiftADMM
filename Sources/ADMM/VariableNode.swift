/// Client reference to a variable in an objective graph
public struct VariableNode {
    /// Associated index of the variable in the graph
    let variableIndex: Int
    
    /// Create the variable-node reference
    ///
    /// - Parameter index: index of the variable data
    init(index: Int) {
        variableIndex = index
    }
}
