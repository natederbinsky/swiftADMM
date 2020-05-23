/// A function that takes in the incoming message and weight for a single variable
/// and returns either nil or the resulting value and weight for that variable
/// - Parameters:
///    - msg: incoming message
///    - weight: weight of incoming message
///
/// - Returns: nil (no intended effect on the variable) or pair with a value and weight
public typealias SingleVarFunc = (_ msg: Double, _ weight: ResultWeight) -> (value: Double, weight: ResultWeight)?

/// Minimization function that is intended infrequently
/// have any effect on a single variable
public class SpyMinimizer: Minimizer {
    /// Variable edge
    private let edge: Edge
    
    /// Associated factor node
    public let factor: Factor
    
    /// Function that dictates when and how
    /// to affect the associated variable
    private let f: SingleVarFunc
    
    /// Create the Spy
    ///
    /// - Parameters:
    ///   - variable: node upon which to "spy"
    ///   - valueFunc: function that dictates when and how to affect the variable
    public init(variable: Variable, valueFunc: @escaping SingleVarFunc) {
        self.factor = variable.problem.addFactor()
        edge = variable.createEdge()
        f = valueFunc
        
        //
        
        connectEdge(edge)
    }
    
    /// Calls the spy's value function and passes through the
    /// result (or zero-weighted incoming message, if nil)
    public final func minimize() {
        let incomingMsg = edge.msg
        
        if let result = f(incomingMsg, edge.weight) {
            edge.setResult(result.value, weight: result.weight)
        } else {
            edge.setResult(incomingMsg, weight: .zero)
        }
    }
}
