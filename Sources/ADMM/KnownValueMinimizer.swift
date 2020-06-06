/// General-purpose factor keeping a variable fixed to a value
///
/// - Parameters:
///   - objective: associated objective graph
///   - variable: variable to keep fixed
///   - value: value for the variable
///
/// - returns: factor node added to the objective graph
public func createKnownValueFactor(objective obj: ObjectiveGraph, variable: VariableNode, value: Double) -> FactorNode {
    let edge = obj.createEdge(variable)
    
    let f: MinimizationFunction = {
        weightedMessages in
        weightedMessages[0].set((value: value, weight: .inf))
    }
    
    return obj.createFactor(edges: [edge], f)
}
