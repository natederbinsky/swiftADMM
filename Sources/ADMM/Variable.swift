/// Representation of a variable node in a problem graph
public class Variable: CustomStringConvertible {
    /// Associated problem
    public let problem: ProblemGraph
    
    /// Variable index
    private let index: Int
    
    /// Variable index and current value
    public var description: String {
        String(format: "Variable #%d = %.5f", index, value)
    }
    
    /// Current variable value (or initial value)
    public var value: Double {
        problem.variableValue(variable: index)
    }
    
    /// Algorithm of the associated problem graph (if true, Three-Weight Algorithm; else ADMM)
    public var twa: Bool {
        problem.twa
    }
    
    /// Creates the variable node
    ///
    /// - Parameters:
    ///   - problem: associated problem graph
    ///   - index: associated variable index
    init(problem: ProblemGraph, index: Int) {
        self.index = index
        self.problem = problem
    }
    
    /// Creates an edge for this variable node
    ///
    /// - Returns: edge associated with this variable
    public func createEdge() -> Edge {
        return problem.addEdge(variable: index)
    }
}
