import Foundation

public enum Algorithm {
    case admm
    case twa
}

typealias VariableEqualityFunction = (UnsafeBufferPointer<Int>, UnsafeBufferPointer<EdgeData>) -> WeightedValue

func _varEqualityADMM(_ edgeIndexes: UnsafeBufferPointer<Int>, _ edgesBuffer: UnsafeBufferPointer<EdgeData>) -> WeightedValue {
    var sum = 0.0
    for edgeIndex in edgeIndexes {
        sum += edgesBuffer[edgeIndex].weightedMessageToVariable.value
    }
    
    return (value: sum / Double(edgeIndexes.count), weight: .std)
}

func _varEqualityTWA(_ edgeIndexes: UnsafeBufferPointer<Int>, _ edgesBuffer: UnsafeBufferPointer<EdgeData>) -> WeightedValue {
    
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
    var equalityFn: VariableEqualityFunction {
        switch self {
        case .admm:
            return _varEqualityADMM
        case .twa:
            return _varEqualityTWA
        }
    }
}

//

public class ObjectiveGraph {
    public let algorithm: Algorithm
    public let convergenceDelta: Double
    public let concurrent: Bool
    
    //
    
    public var learningRate: Double
    
    public var converged: Bool {
        myConverged
    }
    private var myConverged = false
    
    public var iterations: Int {
        myIterations
    }
    private var myIterations = 0
    
    //
    
    private var factors = ContiguousArray<FactorData>()
    private var variables = ContiguousArray<VariableData>()
    private var edges = ContiguousArray<EdgeData>()
    
    //
    
    public var numEdges: Int {
        edges.count
    }
    
    public var numEnabledEdges: Int {
        (edges.filter { $0.enabled }).count
    }
    
    public var numFactors: Int {
        factors.count
    }
    
    public var numEnabledFactors: Int {
        (factors.filter { $0.enabled }).count
    }
    
    public var numVariables: Int {
        variables.count
    }
    
    // ########################################################
    // Edge
    // ########################################################
    
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
    
    public func createVariable(initialValue: Double, initialWeight: MessageWeight) -> VariableNode {
        let index = variables.count
        
        variables.append(VariableData(initValue: initialValue, initWeight: initialWeight))
        
        return VariableNode(index: index)
    }
    
    public func getValue(_ variable: VariableNode) -> Double {
        return variables[variable.variableIndex].value
    }
    
    // ########################################################
    // Factor
    // ########################################################
    
    public func createFactor(edges: [GraphEdge], _ minimizationFunc: @escaping MinimizationFunction) -> FactorNode {
        let index = factors.count
        
        factors.append(FactorData(edges: edges.map { $0.edgeIndex }, f: minimizationFunc))
        
        return FactorNode(index: index)
    }
    
    public func getFactorStatus(_ factor: FactorNode) -> Bool {
        return factors[factor.factorIndex].enabled
    }
    
    func enableFactor(_ factorIndex: Int) {
        factors.withUnsafeMutableBufferPointer { fBuffer in
            if fBuffer[factorIndex].enable() {
                edges.withUnsafeMutableBufferPointer { eBuffer in
                    variables.withUnsafeMutableBufferPointer { vBuffer in
                        fBuffer[factorIndex].edges.withUnsafeBufferPointer { feBuffer in
                            for fEdge in feBuffer {
                                let varIndex = eBuffer[fEdge.edgeIndex].varIndex
                                
                                eBuffer[fEdge.edgeIndex].reset(initInfo: vBuffer[varIndex].initInfo)
                                vBuffer[varIndex].addEnabledEdge(edgeIndex: fEdge.edgeIndex)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func disableFactor(_ factorIndex: Int) {
        factors.withUnsafeMutableBufferPointer { fBuffer in
            if fBuffer[factorIndex].disable() {
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
    
    public func setFactorStatus(_ factor: FactorNode, _ newValue: Bool) {
        if newValue {
            enableFactor(factor.factorIndex)
        } else {
            disableFactor(factor.factorIndex)
        }
    }
    
    // ########################################################
    // Objective
    // ########################################################
    
    private static func _doLeft(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ fi: Int) {
        fBuffer[fi].edges.withUnsafeMutableBufferPointer { wvBuffer in
            for (wvIndex, wv) in wvBuffer.enumerated() {
                wvBuffer[wvIndex].set(eBuffer[wv.edgeIndex].weightedMessageToFactor)
            }
            
            fBuffer[fi].f(wvBuffer)
            
            for wv in wvBuffer {
                let (newValue, newWeight) = wv.get()
                eBuffer[wv.edgeIndex].setResultFromFactor(value: newValue, weight: newWeight)
            }
        }
    }
    
    private static func _doRight(_ variablesBuffer: UnsafeMutableBufferPointer<VariableData>, _ edgesBuffer: UnsafeMutableBufferPointer<EdgeData>, _ varEqualityFn: VariableEqualityFunction, _ learningRate: Double, _ varIndex: Int) {
        // Variable: update enabled list (if necessary)
        do {
            if variablesBuffer[varIndex].enabledNeedsUpdate {
                variablesBuffer[varIndex].enabledEdges.withUnsafeBufferPointer { eiBuffer in
                    variablesBuffer[varIndex].updateEnabledEdges(newEnabled: ContiguousArray<Int>(eiBuffer.filter { edgesBuffer[$0].enabled }))
                }
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
    
    private static func _iterateLeftSerial(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>) {
        for i in 0..<fBuffer.count {
            ObjectiveGraph._doLeft(fBuffer, eBuffer, i)
        }
    }
    
    private static func _iterateLeftConcurrent(_ fBuffer: UnsafeMutableBufferPointer<FactorData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>) {
        DispatchQueue.concurrentPerform(iterations: fBuffer.count) { i in
            ObjectiveGraph._doLeft(fBuffer, eBuffer, i)
        }
    }
    
    private static func _iterateRightSerial(_ vBuffer: UnsafeMutableBufferPointer<VariableData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ varEqualityFn: VariableEqualityFunction, _ learningRate: Double) {
        for i in 0..<vBuffer.count {
            ObjectiveGraph._doRight(vBuffer, eBuffer, varEqualityFn, learningRate, i)
        }
    }
    
    private static func _iterateRightConcurrent(_ vBuffer: UnsafeMutableBufferPointer<VariableData>, _ eBuffer: UnsafeMutableBufferPointer<EdgeData>, _ varEqualityFn: VariableEqualityFunction, _ learningRate: Double) {
        DispatchQueue.concurrentPerform(iterations: vBuffer.count) { i in
            ObjectiveGraph._doRight(vBuffer, eBuffer, varEqualityFn, learningRate, i)
        }
    }
    
    //
    
    private let _varEqualityFn: VariableEqualityFunction
    
    private let _iterateLeftFn: (UnsafeMutableBufferPointer<FactorData>, UnsafeMutableBufferPointer<EdgeData>) -> Void
    private let _iterateRightFn: (UnsafeMutableBufferPointer<VariableData>, UnsafeMutableBufferPointer<EdgeData>, VariableEqualityFunction, Double) -> Void
    
    public init(algorithm: Algorithm, learningRate alpha: Double, convergenceDelta: Double = 1e-5, concurrent: Bool = true) {
        self.algorithm = algorithm
        self.learningRate = alpha
        self.convergenceDelta = convergenceDelta
        self.concurrent = concurrent
        
        //
        
        self._varEqualityFn = algorithm.equalityFn
        
        if concurrent {
            _iterateLeftFn = ObjectiveGraph._iterateLeftConcurrent
            _iterateRightFn = ObjectiveGraph._iterateRightConcurrent
        } else {
            _iterateLeftFn = ObjectiveGraph._iterateLeftSerial
            _iterateRightFn = ObjectiveGraph._iterateRightSerial
        }
    }
    
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
        
        myIterations = 0
        myConverged = false
    }
    
    public func iterate() -> Bool {
        guard !myConverged else { return true }
        
        return edges.withUnsafeMutableBufferPointer { eBuffer in
            factors.withUnsafeMutableBufferPointer { fBuffer in
                _iterateLeftFn(fBuffer, eBuffer)
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
    }
}
