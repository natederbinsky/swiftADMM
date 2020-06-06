public typealias SingleVariableFunction = (WeightedValue) -> WeightedValue?

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
