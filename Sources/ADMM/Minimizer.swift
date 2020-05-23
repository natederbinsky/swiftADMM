/// Protocol dictating that a Minimizer is an object
/// that minimizes a local objective and can retrieve
/// its associated factor node in a problem graph
public protocol Minimizer: AnyObject {
    /// Minimize ${argmin}_x f(x) + \frac{{weight}}{2}(x - {msg})^2$
    func minimize() -> Void
    
    /// Retrieves the associated factor node in the problem graph
    var factor: Factor { get }
}

/// Extension providing minimizers the ability to connect variable edges
/// to the associated factor
public extension Minimizer {
    /// Connect the supplied variable edge to this minimizer's associated factor
    ///
    /// - Parameter edge: variable edge to connect to this minimizer's factor
    func connectEdge(_ edge: Edge) {
        factor.connectEdge(edge: edge, minimizer: self)
    }
}
