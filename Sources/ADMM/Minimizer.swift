
import Foundation

public protocol Minimizer {
    func minimize() -> Void
}

public extension Minimizer {
    func connectVariable(_ v: Variable) -> Edge {
        return v.connectMinimizer(minimizer: self)
    }
}

//

public typealias SingleVarFunc = (_ msg: Double, _ weight: ResultWeight) -> (value: Double, weight: ResultWeight)?

public class SpyMinimizer: Minimizer {
    private var edge: Edge!
    private let f: SingleVarFunc
    
    public init(variable: Variable, valueFunc: @escaping SingleVarFunc) {
        f = valueFunc
        edge = connectVariable(variable)
    }
    
    public final func minimize() {
        if let result = f(edge.msg, edge.weight) {
            edge.setResult(result.value, weight: result.weight)
        } else {
            edge.setResult(edge.msg, weight: .zero)
        }
    }
}

//

public class EqualMinimizer: Minimizer {
    private let _minimize: (EqualMinimizer) -> Void
    private var edges = [Edge]()
    
    var value: Double? {
        return edges.isEmpty ? nil: edges[0].z
    }
    
    //
    
    public init(twa: Bool, vars: Variable...) {
        self._minimize = twa ? EqualMinimizer._minimizeTWA : EqualMinimizer._minimizeADMM
        
        for v in vars {
            edges.append(connectVariable(v))
        }
    }
    
    func addEdge(_ edge: Edge) {
        edges.append(edge)
    }
    
    func reset(_ initialZ: Double, _ initialWeight: ResultWeight) {
        for edge in edges {
            edge.reset(initialZ, initialWeight)
        }
    }
    
    
    public func minimize() {
        _minimize(self)
    }
    
    private static func _msgAvg(_ edgesToInclude: [Edge]) -> Double {
        let sum = edgesToInclude.reduce(0) { (result, element) in
            return result + element.msg
        }
        
        return sum / Double(edgesToInclude.count)
    }
    
    private static func _minimizeTWA(this: EqualMinimizer) {
        let infEdges = this.edges.filter { $0.weight == .inf }
        
        var newVal = 0.0
        var newWeight: ResultWeight = .std
        
        if infEdges.isEmpty {
            let nonZeroEdges = this.edges.filter { $0.weight != .zero }
            
            if nonZeroEdges.isEmpty {
                newVal = _msgAvg(this.edges)
            } else {
                newVal = _msgAvg(nonZeroEdges)
            }
        } else if infEdges.count == 1 {
            newVal = infEdges[0].msg
            newWeight = .inf
        } else {
            let agreement = infEdges[1...].reduce(Double?(infEdges[0].msg)) {
                result, edge in
                if let prevMsg = result {
                    return (prevMsg == edge.msg) ? edge.msg : nil
                } else {
                    return nil
                }
            }
            
            if let agreementVal = agreement {
                newVal = agreementVal
                newWeight = .inf
            } else {
                infEdges.forEach {
                    print($0.msg)
                }
                
                exit(1)
            }
        }
        
        for edge in this.edges {
            edge.setResult(newVal, weight: newWeight)
        }
    }
    
    private static func _minimizeADMM(this: EqualMinimizer) {
        let newZ = _msgAvg(this.edges)
        
        for edge in this.edges {
            edge.setResult(newZ)
        }
    }
}
