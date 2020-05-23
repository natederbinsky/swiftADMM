/// Requires that a variable value be fixed
public class KnownValueMinimizer: Minimizer {
    /// Associated factor node
    public let factor: Factor
    
    /// Associated variable edge
    private let edge: Edge
    
    /// Value to enforce
    public let value: Double
    
    /// Creates the minimizer with an existing factor node
    ///
    /// - Parameters:
    ///   - factor: associated factor node
    ///   - variable: associated variable node
    ///   - value: known value
    public init(factor: Factor, variable: Variable, value: Double) {
        self.factor = factor
        edge = variable.createEdge()
        
        self.value = value
        
        //
        
        connectEdge(edge)
    }

    /// Creates the minimizer with a new factor node
    ///
    /// - Parameters:
    ///   - variable: associated variable node
    ///   - value: known value
    public convenience init(variable: Variable, value: Double) {
        self.init(factor: variable.problem.addFactor(), variable: variable, value: value)
    }
    
    /// Sets the outgoing message as the known value, with infinite weight
    public final func minimize() {
        edge.setResult(value, weight: .inf)
    }
}
