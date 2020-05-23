/// A representation of a node on the left of the problem graph
public class Factor {
    /// Associated problem graph
    private let problem: ProblemGraph
    
    /// Is this node enabled?
    private var enabled = true
    
    /// Edges connected to this node
    private var edges = [Edge]()
    
    /// Associated object to minimize the local objective
    private var minimizer: Minimizer?
    
    /// Ability to get/set whether or not this factor
    /// (and associated edges) will be part of
    /// optimizing the overall objective.
    public var isEnabled: Bool {
        get {
            enabled
        }
        
        set {
            // only do work if there is a
            // change in setting
            if newValue != enabled {
                if newValue {
                    edges.forEach {
                        $0.enable()
                    }
                } else {
                    edges.forEach {
                        $0.disable()
                    }
                }
                enabled = newValue
            }
        }
    }
    
    // *********************************************
    
    /// Creates a new factor in the problem graph
    ///
    /// - Parameter problem: associated problem graph
    init(problem: ProblemGraph) {
        self.problem = problem
    }
    
    /// Associates an existing edge (from a Variable node) to this Factor node
    ///
    /// - Parameters:
    ///   - edge: edge to connect
    ///   - minimizer: minimization function used
    ///
    /// - Important: Minimization function should be the same for all edges (and is enforced via assertion)
    func connectEdge(edge: Edge, minimizer: Minimizer) {
        if let m = self.minimizer {
            assert(ObjectIdentifier(m) == ObjectIdentifier(minimizer))
        } else {
            self.minimizer = minimizer
        }
        
        edges.append(edge)
    }
    
    /// If the factor is enabled, applies the minimization object
    func minimize() {
        if enabled {
            minimizer!.minimize()
        }
    }
    
    /// Resets the factor (currently sets the factor as enabled
    /// without affecting the associated edges)
    func reset() {
        enabled = true
    }
}
