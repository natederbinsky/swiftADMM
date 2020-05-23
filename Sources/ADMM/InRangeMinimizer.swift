/// Enforces that a single variable's value stay within a range
public class InRangeMinimizer: Minimizer {
    /// Associated factor node
    public let factor: Factor
    
    /// Associated variable edge
    private let edge: Edge
    
    /// Lower value bound
    public let lower: Double
    
    /// Upper value bound
    public let upper: Double
    
    /// Creates the minimizer
    ///
    /// - Parameters:
    ///   - factor: associated factor node
    ///   - variable: associated variable node
    ///   - lower: lower bound (inclusive) of the value
    ///   - upper: upper bound (inclusive) of the value
    public init(factor: Factor, variable: Variable, lower: Double, upper: Double) {
        self.factor = factor
        edge = variable.createEdge()
        
        self.lower = lower
        self.upper = upper
        
        //
        
        connectEdge(edge)
    }
    
    /// Creates the minimizer with a new factor node
    ///
    /// - Parameters:
    ///   - variable: associated variable node
    ///   - lower: lower bound (inclusive) of the value
    ///   - upper: upper bound (inclusive) of the value
    public convenience init(variable: Variable, lower: Double, upper: Double) {
        self.init(factor: variable.problem.addFactor(), variable:variable, lower:lower, upper:upper)
    }
    
    /// Enforces the value is in the predefined range
    /// (otherwise stays in place with zero weight)
    public final func minimize() {
        let msg = edge.msg
        
        if msg < lower {
            edge.setResult(lower)
        } else if msg > upper {
            edge.setResult(upper)
        } else {
            edge.setResult(msg, weight: .zero)
        }
    }
}
