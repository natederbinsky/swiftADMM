
enum Direction {
    case left
    case right
}

protocol WeightData {
    var weightToLeft: Double { get set }
    var weightToRight: Double { get set }
}

struct ADMMWeightData: WeightData {
    var weightToLeft: Double {
        get { return Edge.STANDARD }
        set {}
    }
    
    var weightToRight: Double {
        get { return Edge.STANDARD }
        set {}
    }
}

struct TWAWeightData: WeightData {
    var weightToLeft: Double = 0.0
    var weightToRight: Double = 0.0
}

public enum ResultWeight {
    case zero
    case inf
    case std
    
    fileprivate var value: Double {
        switch self {
        case .zero:
            return Double.zero
        case .inf:
            return Double.infinity
        case .std:
            return Edge.STANDARD
        }
    }
}

private extension Double {
    var toResultWeight: ResultWeight {
        get {
            if self.isZero {
                return .zero
            } else if self.isInfinite {
                return .inf
            } else {
                return .std
            }
        }
    }
}

public class Edge {
    static let STANDARD = 1.0
    
    //
    
    var alpha: Double
    
    //
    
    private var x: Double = 0.0
    var z: Double = 0.0
    private var u: Double = 0.0
    
    private var weights: WeightData
    
    private var dir: Direction = .left
    
    private var oldMsg: Double? = nil
    private var oldNewDiff: Double? = nil
    
    //
    
    init(initialValue: Double, initialWeight: ResultWeight, twa: Bool, alpha: Double) {
        self.alpha = alpha
        weights = twa ? TWAWeightData() : ADMMWeightData()
        
        reset(initialValue, initialWeight)
    }
    
    func reset(_ initialZ: Double, _ initialWeight: ResultWeight) {
        x = 0.0
        u = 0.0
        z = initialZ
        
        weights.weightToLeft = initialWeight.value
        weights.weightToRight = 0.0
        
        dir = .left
        
        oldMsg = nil
        oldNewDiff = nil
    }
    
    func pointLeft() {
        dir = .left
        
        if weights.weightToLeft.isInfinite {
            u = 0.0
        } else {
            u += alpha * (x - z)
        }
    }
    
    func pointRight() {
        if let oldMsg = oldMsg {
            oldNewDiff = abs(msg - oldMsg)
        }
        oldMsg = msg
        
        dir = .right
        
        if weights.weightToRight.isInfinite {
            u = 0.0
        }
    }
    
    private var m: Double {
        return x + u
    }
    
    private var n: Double {
        return z - u
    }
    
    var msgDiff: Double? {
        return oldNewDiff
    }
    
    //
    
    public var msg: Double {
        switch dir {
            
        case .left:
            return n
        case .right:
            return m
        }
    }
    
    public var weight: ResultWeight {
        switch dir {

        case .left:
            return weights.weightToLeft.toResultWeight
        case .right:
            return weights.weightToRight.toResultWeight
        }
    }
    
    public func setResult(_ val: Double, weight: ResultWeight = .std) {
        switch dir {
            
        case .left:
            x = val
            weights.weightToRight = weight.value
            
        case .right:
            z = val
            weights.weightToLeft = weight.value
        }
    }
}
