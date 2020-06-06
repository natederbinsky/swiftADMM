/// General-purpose factor keeping a variable within a closed range
///
/// - Parameters:
///   - objective: associated objective graph
///   - variable: variable to keep within range
///   - lower: lower bound of the variable (inclusive)
///   - upper: upper bound of the variable (inclusive)
///
/// - returns: factor node added to the objective graph
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

/// General-purpose factor keeping a variable within a closed range
///
/// - Parameters:
///   - objective: associated objective graph
///   - variable: variable to keep within range
///   - range: closed range over which to limit the variable
///
/// - returns: factor node added to the objective graph
public func createInRangeFactor(objective obj: ObjectiveGraph, variable: VariableNode, range: ClosedRange<Double>) -> FactorNode {
    return createInRangeFactor(objective: obj, variable: variable, lower: range.lowerBound, upper: range.upperBound)
}
