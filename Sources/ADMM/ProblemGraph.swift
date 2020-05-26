/// Bi-partite graph representing an objective function:
/// - left = factors (summed sub-functions)
/// - right = variables
public class ProblemGraph {
    /// When all iteration-over-iteration message differences
    /// are below this value, the algorithm has converged
    public let convergenceThresh: Double
    
    /// If true, solve using the Three-Weight Algorithm (TWA);
    /// otherwise Alternating Direction Method of Multipliers (ADMM)
    public let twa: Bool
    
    /// Number of graph edges
    public var numEdges: Int {
        edges.count
    }
    
    /// Number of enabled edges
    ///
    /// - Important: requires time linear in the number of edges to compute
    public var numEnabledEdges: Int {
        (edges.filter { $0.isEnabled }).count
    }
    
    /// Number of factor nodes
    public var numFactors: Int {
        left.count
    }
    
    /// Number of enabled factors
    ///
    /// - Important: requires time linear in the number of factors to compute
    public var numEnabledFactors: Int {
        (left.filter { $0.isEnabled }).count
    }
    
    /// Number of variable nodes
    public var numVariables: Int {
        right.count
    }
    
    /// Learning rate
    ///
    /// - Important: setting requires time linear in the number of edges; setting alpha during an iteration will result in undefined behavior
    public var alpha: Double {
        get {
            myAlpha
        }
        
        set {
            myAlpha = newValue
            for edge in edges {
                edge.alpha = myAlpha
            }
        }
    }
    private var myAlpha: Double
    
    /// Has the algorithm converged?
    ///
    /// - Important: once the algorithm has converged, no iterations will commence until reinitialization
    public var converged: Bool {
        myConverged
    }
    private var myConverged = false
    
    /// Number of iterations since last reinitialization
    public var iterations: Int {
        myIterations
    }
    private var myIterations = 0
    
    // *********************************************
    
    /// Collection of all edges
    private var edges = ContiguousArray<Edge>()
    
    /// Collection of all factors
    private var left = ContiguousArray<Factor>()
    
    /// Collection of all variables
    /// (or, truly, collections of edges related to each variable)
    private var right = ContiguousArray<EqualValueConstraint>()
    
    /// Iteration over edges
    private let edgeWorker: ContiguousArrayForWorker<Edge>
    
    /// Iteration over factors
    private let leftWorker: ContiguousArrayForWorker<Factor>
    
    /// Iteration over variables
    private let rightWorker: ContiguousArrayForWorker<EqualValueConstraint>
    
    /// Values to initialize edges initially and after reinitialization
    private var variablesInitValue = [Double]()
    
    /// Weights to initialize edges initially and after reinitialization
    private var variablesInitWeight = [ResultWeight]()
    
    // *********************************************
    
    /// Create a new problem graph
    ///
    /// - Parameters:
    ///   - twa: if true, indicates Three-Weight Algorithm; else ADMM
    ///   - alpha: initial learning rate
    ///   - convergenceThresh: message-difference threshold for convergence
    ///   - concurrent: if true, each phase of the iteration uses available cores; else serial
    public init(twa: Bool, alpha: Double, convergenceThresh: Double = 1e-5, concurrent: Bool = true) {
        self.twa = twa
        self.myAlpha = alpha
        self.convergenceThresh = convergenceThresh
        
        edgeWorker = edges.getForWorker(concurrent)
        leftWorker = left.getForWorker(concurrent)
        rightWorker = right.getForWorker(concurrent)
    }
    
    /// Resets the problem graph
    ///
    /// - Important: all variables are reset to initial value/weights; iterations set to 0; convergence bit flipped; factors enabled
    public func reinitialize() {
        for (i, eqConstraint) in right.enumerated() {
            eqConstraint.reset(variablesInitValue[i], variablesInitWeight[i])
        }
        
        left.forEach { $0.reset() }
        
        myIterations = 0
        myConverged = false
    }
    
    /// Adds a new variable to the problem
    ///
    /// - Parameters:
    ///   - initValue: initial variable value
    ///   - initWeight: initial weight associated with initial value
    ///
    /// - Returns: newly created variable node (used to create edges)
    public func addVariable(_ initValue: Double, _ initWeight: ResultWeight = .std) -> Variable {
        right.append(EqualValueConstraint(twa: twa, initialZ: initValue))
        variablesInitValue.append(initValue)
        variablesInitWeight.append(initWeight)
        
        return Variable(problem: self, index: right.count-1)
    }
    
    /// Adds a new factor to the problem
    ///
    /// - Returns: newly created factor node (required for minimizers)
    public func addFactor() -> Factor {
        let factor = Factor(problem: self)
        left.append(factor)
        
        return factor
    }
    
    /// Gets the current value of a variable
    ///
    /// - Parameter variable: index of the variable
    /// - Returns: current value of the variable (or initial value)
    func variableValue(variable: Int) -> Double {
        return right[variable].value
    }
    
    /// Adds an edge to a variable
    ///
    /// - Parameter variable: index of the variable
    /// - Returns: variable-associated edge
    func addEdge(variable: Int) -> Edge {
        let constraint = right[variable]
        
        let newEdge = Edge(right: constraint, twa: twa, initialAlpha: myAlpha, initialValue: variablesInitValue[variable], initialWeight: variablesInitWeight[variable])
        
        edges.append(newEdge)
        constraint.addEdge(newEdge)
        
        return newEdge
    }
    
    /// Performs one full iteration of the algorithm on the current problem graph
    /// (assuming the algorithm hasn't already converged)
    ///
    /// - Returns: has the algorithm converged?
    public func iterate() -> Bool {
        guard !myConverged else { return true }
        
        (leftWorker(left)) { $0.minimize() }
        (edgeWorker(edges)) { $0.pointRight() }
        (rightWorker(right)) { $0.enforce() }
        (edgeWorker(edges)) { $0.pointLeft() }
        
        myIterations += 1
        
        return edges.withUnsafeBufferPointer { buffer in
            for e in buffer {
                if e.isEnabled {
                    guard let msgDiff = e.msgDiff else { return false }
                    if msgDiff > convergenceThresh {
                        return false
                    }
                }
            }
            
            myConverged = true
            return true
        }
    }
}
