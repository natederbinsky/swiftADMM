import Foundation

typealias MinimizerWrapper = ObjectWrapper<Minimizer>

//

public class ProblemGraph {
    public let convergenceThresh: Double
    public let twa: Bool
    
    public var numEdges: Int {
        return edges.count
    }
    
    public var numLeft: Int {
        return left.count
    }
    
    public var numRight: Int {
        return right.count
    }
    
    //
    
    // Setting alpha is definitely a bad idea during an iteration,
    // both in terms of being a bad idea, but also will result
    // in unclear behavior
    private var myAlpha: Double
    public var alpha: Double {
        get {
            return myAlpha
        }
        
        set {
            myAlpha = newValue
            for edge in edges {
                edge.alpha = myAlpha
            }
        }
    }
    
    private var myConverged = false
    public var converged: Bool {
        return myConverged
    }
    
    private var myIterations = 0
    public var iterations: Int {
        return myIterations
    }
    
    //
    
    private var edges = [Edge]()
    private var left = [Minimizer]()
    private var right = [EqualMinimizer]()
    
    private let edgeWorker: ArrayForWorker<Edge>
    private let minimizerWorker: ArrayForWorker<Minimizer>
    
    private var variablesInitValue = [Double]()
    private var variablesInitWeight = [ResultWeight]()
    private var leftCheck = [MinimizerWrapper:Int]()
    
    //
    
    public init(twa: Bool, alpha: Double, convergenceThresh: Double = 1e-5, concurrent: Bool = true) {
        self.twa = twa
        self.myAlpha = alpha
        self.convergenceThresh = convergenceThresh
        
        edgeWorker = edges.getForWorker(concurrent)
        minimizerWorker = left.getForWorker(concurrent)
    }
    
    public func reinitialize() {
        for (i, eqMinimizer) in right.enumerated() {
            eqMinimizer.reset(variablesInitValue[i], variablesInitWeight[i])
        }
        
        myIterations = 0
        myConverged = false
    }
    
    public func addVariable(_ initValue: Double, _ initWeight: ResultWeight = .std) -> Variable {
        right.append(EqualMinimizer(twa: twa))
        variablesInitValue.append(initValue)
        variablesInitWeight.append(initWeight)
        
        return Variable(problem: self, index: right.count-1)
    }
    
    func variableValue(variable: Int) -> Double {
        if let rtVal = right[variable].value {
            return rtVal
        } else {
            return variablesInitValue[variable]
        }
    }
    
    func addEdge(variable: Int, minimizer: Minimizer) -> Edge {
        let newEdge = Edge(initialValue: variablesInitValue[variable], initialWeight: variablesInitWeight[variable], twa: twa, alpha: myAlpha)
        edges.append(newEdge)
        
        let minChecker = MinimizerWrapper(minimizer)
        let minimizerCount = leftCheck[minChecker, default: 0]
        if minimizerCount == 0 {
            left.append(minimizer)
        }
        leftCheck[minChecker] = minimizerCount + 1
        
        right[variable].addEdge(newEdge)
        
        return newEdge
    }
    
    public func iterate() -> Bool {
        if myConverged {
            return true
        }
        
        (minimizerWorker(left)) { $0.minimize() }
        (edgeWorker(edges)) { $0.pointRight() }
        (minimizerWorker(right)) { $0.minimize() }
        (edgeWorker(edges)) { $0.pointLeft() }
        
        myIterations += 1
        
        return edges.withUnsafeBufferPointer { buffer in
            for e in buffer {
                guard let msgDiff = e.msgDiff else { return false }
                if msgDiff > convergenceThresh {
                    return false
                }
            }
            
            myConverged = true
            return true
        }
    }
}
