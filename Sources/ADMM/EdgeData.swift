public enum MessageWeight {
    case zero
    case inf
    case std
    
    public var value: Double {
        switch self {
        case .zero:
            return Double.zero
        case .inf:
            return Double.infinity
        case .std:
            return 1.0
        }
    }
}

protocol MessageWeightData {
    var weightToLeft: MessageWeight { get set }
    var weightToRight: MessageWeight { get set }
}

struct SingleWeightData: MessageWeightData {
    var weightToLeft: MessageWeight {
        get { .std }
        set {}
    }
    
    var weightToRight: MessageWeight {
        get { .std }
        set {}
    }
}

struct ThreeWeightData: MessageWeightData {
    var weightToLeft: MessageWeight = .zero
    var weightToRight: MessageWeight = .zero
}

extension Algorithm {
    var weightData: MessageWeightData {
        switch self {
        case .admm:
            return SingleWeightData()
        case .twa:
            return ThreeWeightData()
        }
    }
}

struct EdgeData {
    let varIndex: Int
    
    var x: Double = 0.0
    var u: Double = 0.0
    var z: Double = 0.0
    
    private var oldMsg: Double? = nil
    var msgDiff: Double? = nil
    
    var weights: MessageWeightData
    
    var enabled: Bool = true
    
    //
    
    var m: Double {
        return x + u
    }
    
    var n: Double {
        return z - u
    }
    
    var weightedMessageToFactor: WeightedValue {
        return (value: n, weight: weights.weightToLeft)
    }
    
    var weightedMessageToVariable: WeightedValue {
        return (value: m, weight: weights.weightToRight)
    }
    
    //
    
    init(algorithm: Algorithm, varIndex: Int, initInfo: WeightedValue) {
        self.weights = algorithm.weightData
        self.varIndex = varIndex
        
        reset(initInfo: initInfo)
    }
    
    //
    
    mutating func setResultFromFactor(value: Double, weight: MessageWeight) {
        x = value
        weights.weightToRight = weight
        
        //
        
        if let oldMsg = oldMsg {
            msgDiff = abs(n - oldMsg)
        }
        oldMsg = n
        
        if weights.weightToRight == .inf {
            u = 0.0
        }
    }
    
    mutating func setResultFromVariable(value: Double, weight: MessageWeight, alpha: Double) {
        z = value
        weights.weightToLeft = weight
        
        //
        
        if weights.weightToLeft == .inf {
            u = 0.0
        } else {
            u += alpha * (x - z)
        }
    }
    
    mutating func reset(initInfo: WeightedValue) {
        enabled = true
        
        x = 0.0
        u = 0.0
        z = initInfo.value
        
        weights.weightToLeft = initInfo.weight
        weights.weightToRight = .zero
        
        oldMsg = nil
        msgDiff = nil
    }
    
    mutating func disable() {
        enabled = false
    }
}
