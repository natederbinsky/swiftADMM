/// A function that, given value/weight, may return an output value/weight
public typealias SingleVariableFunction = (WeightedValue) -> WeightedValue?

/// General-purpose factor that hides (i.e., zero-weight output) until a supplied
/// function provides an output value/weight
///
/// - Parameters:
///   - objective: associated objective graph
///   - variable: variable to keep within range
///   - valueFunc: function that decides when to assert a non-zero weighted value
///
/// - returns: factor node added to the objective graph
public func createSpyFactor(objective obj: ObjectiveGraph, variable: VariableNode, valueFunc: @escaping SingleVariableFunction) -> FactorNode {
    let edge = obj.createEdge(variable)
    
    let f: MinimizationFunction = {
        weightedMessages in
        
        let incoming = weightedMessages[0].get()
        
        if let result = valueFunc(incoming) {
            weightedMessages[0].set(result)
        } else {
            weightedMessages[0].set((value: incoming.value, weight: .zero))
        }
    }
    
    return obj.createFactor(edges: [edge], f)
}
