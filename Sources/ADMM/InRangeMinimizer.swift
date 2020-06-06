public func createInRangeFactor(objective obj: ObjectiveGraph, variable: VariableNode, lower: Double, upper: Double) -> FactorNode {
    
    let edges = [obj.createEdge(variable)]
    let f: MinimizationFunction = {
        weightedMessages in
        
        let (msg, _) = weightedMessages[0].get()
        
        if msg < lower {
            weightedMessages[0].set((value: lower, weight: .std))
        } else if msg > upper {
            weightedMessages[0].set((value: upper, weight: .std))
        } else {
            weightedMessages[0].set((value: msg, weight:.zero))
        }
    }
    
    return obj.createFactor(edges: edges, f)
}
