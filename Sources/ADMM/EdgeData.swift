/// Message-weight possibilities
public enum MessageWeight {
    /// zero weight (no confidence)
    case zero
    
    /// infinite weight (certain)
    case inf
    
    /// standard weight (1 vote)
    case std
    
    /// Numeric value associated with the weight
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

/// Abstraction for efficient processing of weights
/// in variants of ADMM
private protocol MessageWeightData {
    /// Weight to factors
    var weightToLeft: MessageWeight { get set }
    
    /// Weight to variables
    var weightToRight: MessageWeight { get set }
}

/// Implementation that always weights messages
/// using the standard weight
private struct SingleWeightData: MessageWeightData {
    var weightToLeft: MessageWeight {
        get { .std }
        set {}
    }
    
    var weightToRight: MessageWeight {
        get { .std }
        set {}
    }
}

/// Implementation that supports bi-direction three-weights
private struct ThreeWeightData: MessageWeightData {
    var weightToLeft: MessageWeight = .zero
    var weightToRight: MessageWeight = .zero
}

extension Algorithm {
    /// Weight implementation associated with each algorithm
    fileprivate var weightData: MessageWeightData {
        switch self {
        case .admm:
            return SingleWeightData()
        case .twa:
            return ThreeWeightData()
        }
    }
}

/// Data associated with each edge of an objective graph
struct EdgeData {
    /// Index of the associated variable
    let varIndex: Int
    
    /// Value set by the factor
    var x: Double = 0.0
    
    /// Cumulative value difference
    var u: Double = 0.0
    
    /// Value set by the variable
    var z: Double = 0.0
    
    /// Last message (from variable)
    private var oldMsg: Double? = nil
    
    /// Last message difference (from variable)
    /// that is used to determine convergence
    var msgDiff: Double? = nil
    
    /// Message weights
    private var weights: MessageWeightData
    
    /// Is this edge enabled?
    var enabled: Bool = true
    
    //
    
    /// Message from the factor
    private var m: Double {
        return x + u
    }
    
    /// Message from the variable
    private var n: Double {
        return z - u
    }
    
    /// Weighted message to the factor
    var weightedMessageToFactor: WeightedValue {
        return (value: n, weight: weights.weightToLeft)
    }
    
    /// Weighted message to the variable
    var weightedMessageToVariable: WeightedValue {
        return (value: m, weight: weights.weightToRight)
    }
    
    //
    
    /// Creates a new edge for an existing variable
    ///
    /// - Parameters:
    ///   - algorithm: indicates the weighting scheme to implement
    ///   - varIndex: index of associated variable
    ///   - initInfo: initial value/weight
    init(algorithm: Algorithm, varIndex: Int, initInfo: WeightedValue) {
        self.weights = algorithm.weightData
        self.varIndex = varIndex
        
        reset(initInfo: initInfo)
    }
    
    /// Resets the edge data
    ///
    /// - Parameter initInfo: initial value/weight for the edge
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
    
    //
    
    /// Changes data based upon value/weight computed by the factor
    ///
    /// - Parameter value: factor-determined value
    /// - Parameter value: factor-determined weight
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
    
    /// Changes data based upon value/weight computed by the variable
    ///
    /// - Parameter value: variable-determined value
    /// - Parameter value: variable-determined weight
    /// - Parameter alpha: learning rate for updating u
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
    
    /// Marks the edge as inactive
    mutating func disable() {
        enabled = false
    }
}
