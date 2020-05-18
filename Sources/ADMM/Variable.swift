
public class Variable: CustomStringConvertible {
    private let index: Int
    private let problem: ProblemGraph
    
    public var description: String {
        return String(format: "Variable #%d = %.5f", index, value)
    }
    
    public var value: Double {
        return problem.variableValue(variable: index)
    }
    
    public var twa: Bool {
        return problem.twa
    }
    
    init(problem: ProblemGraph, index: Int) {
        self.index = index
        self.problem = problem
    }
    
    func connectMinimizer(minimizer: Minimizer) -> Edge {
        return problem.addEdge(variable: index, minimizer: minimizer)
    }
}
