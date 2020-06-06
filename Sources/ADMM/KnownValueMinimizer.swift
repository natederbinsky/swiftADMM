public func createKnownValueFactor(objective obj: ObjectiveGraph, variable: VariableNode, value: Double) -> FactorNode {
    let edge = obj.createEdge(variable)
    let f: MinimizationFunction = {
        weightedMessages in
        weightedMessages[0].set((value: value, weight: .inf))
    }
    
    return obj.createFactor(edges: [edge], f)
}
