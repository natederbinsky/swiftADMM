import Foundation

/// Implemented algorithms
public enum Algorithm {
    /// Alternating Direction Method of Multipliers
    case admm
    
    /// Three-Weight Algorithm
    case twa
}

/// Method by which to force that all edges of a variable agree on a single weighted value
typealias VariableEqualityFunction = (UnsafeBufferPointer<Int>, UnsafeBufferPointer<EdgeData>) -> WeightedValue

/// ADMM implementation of variable equality (average)
///
/// - Parameters:
///   - edgeIndexes: indexes of edges to consider
///   - edgesBuffer: access to buffer data
///
/// - returns: agreed-upon value and weight
private func _varEqualityADMM(_ edgeIndexes: UnsafeBufferPointer<Int>, _ edgesBuffer: UnsafeBufferPointer<EdgeData>) -> WeightedValue {
    var sum = 0.0
    for edgeIndex in edgeIndexes {
        sum += edgesBuffer[edgeIndex].weightedMessageToVariable.value
    }
    
    return (value: sum / Double(edgeIndexes.count), weight: .std)
}

/// Three-Weight Algorithm implementation of variable equality:
/// - Infinite weight wins immediately (assumes all are identical)
/// - Otherwise average of standard-weighted values (or all, if only zero-weighted)
///
/// - Parameters:
///   - edgeIndexes: indexes of edges to consider
///   - edgesBuffer: access to buffer data
///
/// - returns: agreed-upon value and weight
private func _varEqualityTWA(_ edgeIndexes: UnsafeBufferPointer<Int>, _ edgesBuffer: UnsafeBufferPointer<EdgeData>) -> WeightedValue {
    
    var allSum = 0.0
    var nzSum = 0.0
    var nzCount = 0
    
    for edgeIndex in edgeIndexes {
        let (value, weight) = edgesBuffer[edgeIndex].weightedMessageToVariable
        
        if weight == .inf {
            return (value: value, weight: weight)
        } else if weight != .zero {
            nzSum += value
            nzCount += 1
        }
        
        allSum += value
    }
    
    if nzCount > 0 {
        return (value: nzSum / Double(nzCount), weight: .std)
    } else {
        return (value: allSum / Double(edgeIndexes.count), weight: .std)
    }
}

extension Algorithm {
    /// Method of enforcing variable equality for each algorithm
    var equalityFn: VariableEqualityFunction {
        switch self {
        case .admm:
            return _varEqualityADMM
        case .twa:
            return _varEqualityTWA
        }
    }
}

// Represents the bi-partite graph (factors/variables)
// for an objective function
public class ObjectiveGraph {
    /// Algorithm being implemented
    public let algorithm: Algorithm
    
    /// Convergence criterion
    public var convergenceDelta: Double
    
    /// Are multiple threads being utilized?
    public let concurrent: Bool
    
    // Learning rate (alpha)
    public var learningRate: Double
    
    /// Has the algorithm converged?
    public var converged: Bool {
        myConverged
    }
    private var myConverged = false
    
    /// How many iterations since initialization/convergence?
    public var iterations: Int {
        myIterations
    }
    private var myIterations = 0
    
    //
    
    /// All factors
    private var factors = ContiguousArray<FactorData>()
    
    /// All variables
    private var variables = ContiguousArray<VariableData>()
    
    /// All edges
    private var edges = ContiguousArray<EdgeData>()
    
    /// Indexes of enabled factors
    private var enabledFactors = Set<Int>()
    
    //
    
    // All callbacks
    private var callbackIterate = ContiguousArray<()->Void>()
    private var callbackReinit = ContiguousArray<()->Void>()
    
    //
    
    /// How many edges are in the graph?
    public var numEdges: Int {
        edges.count
    }
    
    /// How many edges in the graph are enabled?
    ///
    /// - Note: computation time linear in the number of edges
    public var numEnabledEdges: Int {
        (edges.filter { $0.enabled }).count
    }
    
    /// How many factors are in the graph?
    public var numFactors: Int {
        factors.count
    }
    
    /// How many factors are enabled?
    public var numEnabledFactors: Int {
        enabledFactors.count
    }
    
    /// How many variables are in the graph?
    public var numVariables: Int {
        variables.count
    }
    
    // ########################################################
    // Edge
    // ########################################################
    
    /// Create an edge associated with an existing variable
    ///
    /// - Parameter variable: reference to an existing variable to which to connect the edge
    /// - returns: reference to the newly created edge
    public func createEdge(_ variable: VariableNode) -> GraphEdge {
        let variableIndex = variable.variableIndex
        let edgeIndex = edges.count
        
        edges.append(EdgeData(algorithm: algorithm, varIndex: variableIndex, initInfo: variables[variableIndex].initInfo))
        variables[variableIndex].addEdge(edgeIndex: edgeIndex)
        
        return GraphEdge(index: edgeIndex)
    }
    
    // ########################################################
    // Variable
    // ########################################################
    
    /// Create a new variable
    ///
    /// - Parameter initialValue: initial value for the variable
    /// - Parameter initialWeight: initial weight for the variable's initial value
    /// - returns: reference to the newly created variable
    public func createVariable(initialValue: Double, initialWeight: MessageWeight) -> VariableNode {
        let index = variables.count
        
        variables.append(VariableData(initValue: initialValue, initWeight: initialWeight))
        
        return VariableNode(index: index)
    }
    
    /// Gets the variable value using an unsafe buffer (slightly faster than subscript)
    ///
    /// - Parameter variable: reference to variable
    /// - returns: current value of the supplied variable
    public func getValueUnsafe(_ variable: VariableNode) -> Double {
        variables.withUnsafeBufferPointer { vBuffer in
            return vBuffer[variable.variableIndex].value
        }
    }
    
    /// Gets the variable value
    ///
    /// - Parameter variable: reference to variable
    /// - returns: current value of the supplied variable
    public subscript(variable: VariableNode) -> Double {
        return variables[variable.variableIndex].value
    }
    
    // ########################################################
    // Factor
    // ########################################################
    
    /// Creates a new factor
    ///
    /// - Parameter edges: existing variable edges, in order that they be supplied to the minimization function
    /// - Parameter minimizationFunc: function to minimize the local objective
    /// - returns: reference to newly created factor
    public func createFactor(edges: [GraphEdge], _ minimizationFunc: @escaping MinimizationFunction) -> FactorNode {
        let index = factors.count
        
        factors.append(FactorData(edges: edges.map { $0.edgeIndex }, f: minimizationFunc))
        enabledFactors.insert(index)
        
        return FactorNode(index: index)
    }
    
    /// Get/set the status (enabled vs not) of a factor
    ///
    /// - Parameter factor: reference to existing factor
    /// - returns: is the factor enabled?
    public subscript(factor: FactorNode) -> Bool {
        get {
            return factors[factor.factorIndex].enabled
        }
        
        set {
            if newValue {
                enableFactor(factor.factorIndex)
            } else {
                disableFactor(factor.factorIndex)
            }
        }
    }
    
    /// Enables a factor
    ///
    /// - Parameter factorIndex: index of the factor data
    private func enableFactor(_ factorIndex: Int) {
        factors.withUnsafeMutableBufferPointer { fBuffer in
            // Don't do duplicate work!
            if fBuffer[factorIndex].enable() {
                enabledFactors.insert(factorIndex)
                
                edges.withUnsafeMutableBufferPointer { eBuffer in
                    variables.withUnsafeMutableBufferPointer { vBuffer in
                        fBuffer[factorIndex].edges.withUnsafeBufferPointer { feBuffer in
                            for fEdge in feBuffer {
                                let varIndex = eBuffer[fEdge.edgeIndex].varIndex
                                
                                eBuffer[fEdge.edgeIndex].reset(initInfo: (value: vBuffer[varIndex].value, weight: .std))
                                vBuffer[varIndex].addEnabledEdge(edgeIndex: fEdge.edgeIndex)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Disables a factor
    ///
    /// - Parameter factorIndex: index of the factor data
    private func disableFactor(_ factorIndex: Int) {
        factors.withUnsafeMutableBufferPointer { fBuffer in
            // Don't do duplicate work!
            if fBuffer[factorIndex].disable() {
                enabledFactors.remove(factorIndex)
                
                edges.withUnsafeMutableBufferPointer { eBuffer in
                    variables.withUnsafeMutableBufferPointer { vBuffer in
                        fBuffer[factorIndex].edges.withUnsafeBufferPointer { feBuffer in
                            for fEdge in feBuffer {
                                let varIndex = eBuffer[fEdge.edgeIndex].varIndex
                                
                                eBuffer[fEdge.edgeIndex].disable()
                                vBuffer[varIndex].forceEnabledEdgesUpdate()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ########################################################
    // Iteration
    // ########################################################
    
    /// Iteration work for a single factor
    ///
    /// - Parameters:
    ///   - fBuffer: access to factor data
    ///   - eBuffer: access to edge data
    ///   - fi: index of factor
    private static func _doLeft(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ fi: Int) {
        fBuffer[fi].edges.withUnsafeMutableBufferPointer { wvBuffer in
            /// Setup incoming messages
            for (wvIndex, wv) in wvBuffer.enumerated() {
                wvBuffer[wvIndex].set(eBuffer[wv.edgeIndex].weightedMessageToFactor)
            }
            
            /// Local minimization
            fBuffer[fi].f(wvBuffer)
            
            /// Pass along outgoing weighted values
            for wv in wvBuffer {
                let (newValue, newWeight) = wv.get()
                eBuffer[wv.edgeIndex].setResultFromFactor(value: newValue, weight: newWeight)
            }
        }
    }
    
    /// Iteration work for a single variable
    ///
    /// - Parameters:
    ///   - variablesBuffer: access to variable data
    ///   - edgesBuffer: access to edge data
    ///   - varEqualityFn: method of enforcing equality
    ///   - learningRate: alpha for u-update
    ///   - varIndex: index of variable
    private static func _doRight(_ variablesBuffer: UnsafeMutableBufferPointer<VariableData>, _ edgesBuffer: UnsafeMutableBufferPointer<EdgeData>, _ varEqualityFn: VariableEqualityFunction, _ learningRate: Double, _ varIndex: Int) {
        // Variable: update enabled list (if necessary)
        do {
            if variablesBuffer[varIndex].enabledNeedsUpdate {
                var newEnabled = ContiguousArray<Int>()
                
                variablesBuffer[varIndex].enabledEdges.withUnsafeBufferPointer { eiBuffer in
                    for enabledEdgeIndex in eiBuffer {
                        if edgesBuffer[enabledEdgeIndex].enabled {
                            newEnabled.append(enabledEdgeIndex)
                        }
                    }
                }
                
                variablesBuffer[varIndex].updateEnabledEdges(newEnabled: newEnabled)
            }
        }
        
        variablesBuffer[varIndex].enabledEdges.withUnsafeBufferPointer { eiBuffer in
            // (z, weight) = ADMM/TWA()
            let (newZ, newWeightRight) = varEqualityFn(eiBuffer, UnsafeBufferPointer<EdgeData>(edgesBuffer))
            
            // Variable: update value (z)
            variablesBuffer[varIndex].updateValue(newValue: newZ)
            
            // Edges: set result (z, weight)
            for edgeIndex in eiBuffer {
                edgesBuffer[edgeIndex].setResultFromVariable(value: newZ, weight: newWeightRight, alpha: learningRate)
            }
        }
    }
    
    /// Iterate over all factors serially
    ///
    /// - Parameter fBuffer: access to factor data
    /// - Parameter eBuffer: access to edge data
    private static func _iterateLeftSerial(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>) {
        for i in 0..<fBuffer.count {
            ObjectiveGraph._doLeft(fBuffer, eBuffer, i)
        }
    }
    
    /// Iterate over all factors concurrently
    ///
    /// - Parameter fBuffer: access to factor data
    /// - Parameter eBuffer: access to edge data
    private static func _iterateLeftConcurrent(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>) {
        DispatchQueue.concurrentPerform(iterations: fBuffer.count) { i in
            ObjectiveGraph._doLeft(fBuffer, eBuffer, i)
        }
    }
    
    /// Iterate over all *enabled* factors serially
    ///
    /// - Parameters:
    ///   - fBuffer: access to factor data
    ///   - eBuffer: access to edge data
    ///   - enabledFactors: indexes of enabled factors
    private static func _iterateLeftEnabledSerial(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ enabledFactors: Set<Int>) {
        for fIndex in enabledFactors {
            ObjectiveGraph._doLeft(fBuffer, eBuffer, fIndex)
        }
    }
    
    /// Iterate over all *enabled* factors concurrently
    ///
    /// - Parameters:
    ///   - fBuffer: access to factor data
    ///   - eBuffer: access to edge data
    ///   - enabledFactors: indexes of enabled factors
    private static func _iterateLeftEnabledConcurrent(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ enabledFactors: Set<Int>) {
        let fastEnabledFactors = ContiguousArray<Int>(enabledFactors)

        fastEnabledFactors.withUnsafeBufferPointer { fastBuffer in
            DispatchQueue.concurrentPerform(iterations: fastBuffer.count) { i in
                ObjectiveGraph._doLeft(fBuffer, eBuffer, fastBuffer[i])
            }
        }
    }
    
    /// Iterate over all variables serially
    ///
    /// - Parameters:
    ///   - vBuffer: access to variable data
    ///   - eBuffer: access to edge data
    ///   - varEqualityFn: method of enforcing equality
    ///   - learningRate: alpha for u-update
    private static func _iterateRightSerial(_ vBuffer: UnsafeMutableBufferPointer<VariableData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ varEqualityFn: VariableEqualityFunction, _ learningRate: Double) {
        for i in 0..<vBuffer.count {
            ObjectiveGraph._doRight(vBuffer, eBuffer, varEqualityFn, learningRate, i)
        }
    }
    
    /// Iterate over all variables concurrently
    ///
    /// - Parameters:
    ///   - vBuffer: access to variable data
    ///   - eBuffer: access to edge data
    ///   - varEqualityFn: method of enforcing equality
    ///   - learningRate: alpha for u-update
    private static func _iterateRightConcurrent(_ vBuffer: UnsafeMutableBufferPointer<VariableData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ varEqualityFn: VariableEqualityFunction, _ learningRate: Double) {
        DispatchQueue.concurrentPerform(iterations: vBuffer.count) { i in
            ObjectiveGraph._doRight(vBuffer, eBuffer, varEqualityFn, learningRate, i)
        }
    }
    
    //
    
    /// Algorithm-specific method of enforcing equality of variable edges
    private let _varEqualityFn: VariableEqualityFunction
    
    /// Method of iterating over factors
    private let _iterateLeftFn: (UnsafeMutableBufferPointer<FactorData>, UnsafeMutableBufferPointer<EdgeData>) -> Void
    
    /// Method of iterating over enabled factors
    private let _iterateLeftEnabledFn: (UnsafeMutableBufferPointer<FactorData>, UnsafeMutableBufferPointer<EdgeData>, Set<Int>) -> Void
    
    /// Method of iterating over variables
    private let _iterateRightFn: (UnsafeMutableBufferPointer<VariableData>, UnsafeMutableBufferPointer<EdgeData>, VariableEqualityFunction, Double) -> Void
    
    /// Perform an iteration of the algorithm over the objective
    ///
    /// - returns: has the algorithm converged?
    public func iterate() -> Bool {
        guard !myConverged else { return true }
        
        let result: Bool = edges.withUnsafeMutableBufferPointer { eBuffer in
            factors.withUnsafeMutableBufferPointer { fBuffer in
                let enabledProp = Double(enabledFactors.count) / Double(fBuffer.count)
                if enabledProp < 0.15 {
                    _iterateLeftEnabledFn(fBuffer, eBuffer, enabledFactors)
                } else {
                    _iterateLeftFn(fBuffer, eBuffer)
                }
            }
                
            variables.withUnsafeMutableBufferPointer { vBuffer in
                _iterateRightFn(vBuffer, eBuffer, _varEqualityFn, learningRate)
            }
            
            myIterations += 1
            
            for e in UnsafeBufferPointer(eBuffer) {
                if e.enabled {
                    guard let msgDiff = e.msgDiff else { return false }
                    if msgDiff > convergenceDelta {
                        return false
                    }
                }
            }
            
            myConverged = true
            return myConverged
        }
        
        //
        
        for f in callbackIterate {
            f()
        }
        
        return result
    }
    
    /// Adds a function that is called *after* objective-graph iteration
    ///
    /// - Note: is not called if iteration is attempted on a converged graph
    ///
    /// - Parameter f: function to be called
    public func addIterationCallback(_ f: @escaping ()->Void) {
        callbackIterate.append(f)
    }
    
    // ########################################################
    // (Re-)Initialization
    // ########################################################
    
    /// Creates an empty objective graph
    ///
    /// - Parameters:
    ///   - algorithm: solving algorithm to use
    ///   - learningRate: initial alpha value
    ///   - convergenceDelta: initial convergence threshold
    ///   - concurrent: use multiple threads when iterating?
    public init(algorithm: Algorithm, learningRate alpha: Double, convergenceDelta: Double = 1e-5, concurrent: Bool = true) {
        self.algorithm = algorithm
        self.learningRate = alpha
        self.convergenceDelta = convergenceDelta
        self.concurrent = concurrent
        
        //
        
        self._varEqualityFn = algorithm.equalityFn
        
        if concurrent {
            _iterateLeftFn = ObjectiveGraph._iterateLeftConcurrent
            _iterateLeftEnabledFn = ObjectiveGraph._iterateLeftEnabledConcurrent
            _iterateRightFn = ObjectiveGraph._iterateRightConcurrent
        } else {
            _iterateLeftFn = ObjectiveGraph._iterateLeftSerial
            _iterateLeftEnabledFn = ObjectiveGraph._iterateLeftEnabledSerial
            _iterateRightFn = ObjectiveGraph._iterateRightSerial
        }
    }
    
    /// Re-initialize the objective graph: variables set to initial values/weights, all factors enabled, iterations=0, converged=false
    public func reinitialize() {
        edges.withUnsafeMutableBufferPointer { eBuffer in
            variables.withUnsafeMutableBufferPointer { vBuffer in
                for (vi, v) in vBuffer.enumerated() {
                    vBuffer[vi].reset()
                    
                    vBuffer[vi].edges.withUnsafeMutableBufferPointer { veBuffer in
                        for varEdgeIndex in veBuffer {
                            eBuffer[varEdgeIndex].reset(initInfo: v.initInfo)
                        }
                    }
                }
            }
        }
        
        factors.withUnsafeMutableBufferPointer { fBuffer in
            for fi in 0..<fBuffer.count {
                fBuffer[fi].reset()
            }
        }
        enabledFactors = Set<Int>(0..<factors.count)
        
        myIterations = 0
        myConverged = false
        
        //
        
        for f in callbackReinit {
            f()
        }
    }
    
    /// Adds a function that is called *after* objective-graph reinitialization
    ///
    /// - Parameter f: function to be called
    public func addReinitCallback(_ f: @escaping ()->Void) {
        callbackReinit.append(f)
    }
}
