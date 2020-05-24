/// Message-weight options
public enum ResultWeight {
    /// Zero weight (no information)
    case zero
    
    /// Infinite weight (certainty)
    case inf
    
    /// Standard weight
    case std
    
    /// Numerical value of the weight
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

/// Abstraction over bidirectional weights
/// to avoid extra space/time for ADMM
protocol WeightData {
    /// Weight of message sent to factors
    var weightToLeft: ResultWeight { get set }
    
    /// Weight of message sent to variables
    var weightToRight: ResultWeight { get set }
}

/// ADMM implementation always uses standard weight
struct ADMMWeightData: WeightData {
    var weightToLeft: ResultWeight {
        get { .std }
        set {}
    }
    
    var weightToRight: ResultWeight {
        get { .std }
        set {}
    }
}

/// TWA implementation uses any of three values
struct TWAWeightData: WeightData {
    var weightToLeft: ResultWeight = .zero
    var weightToRight: ResultWeight = .zero
}

/// Indicates the side of
/// the bipartite graph that
/// is being operated on
enum Direction {
    /// Processing factors
    case left
    
    /// Processing variables
    case right
}

/// Facilitates access to edge information within
/// an executing problem graph
public class Edge {
    /// Reference to object maintaining equal values
    /// across edges after right
    private let right: EqualValueConstraint
    
    // *********************************************
    
    /// Learning rate for this edge
    var alpha: Double
    
    /// Dictates whether this edge is enabled
    private var enabled: Bool = true
    
    /// Is this edge enabled?
    public var isEnabled: Bool {
        enabled
    }
    
    // *********************************************
    
    /// Value set by the left
    private var x: Double = 0.0
    
    /// Value set by the right
    var z: Double = 0.0
    
    /// Cumulative value difference
    private var u: Double = 0.0
    
    /// Weights associated with left/right messages
    private var weights: WeightData
    
    /// Current direction of processing
    private var dir: Direction = .left
    
    /// Last message value from left
    private var oldMsg: Double? = nil
    
    /// Message delta from left over the last two iterations
    var msgDiff: Double? = nil
    
    // *********************************************
    
    /// Construct a new problem-graph edge
    ///
    /// - Parameters:
    ///   - right: associated variable constraint
    ///   - twa: should this edge implement the three-weight algorithm?
    ///   - initialAlpha: initial learning rate
    ///   - initialValue: initial z value
    ///   - initialWeight: initial weight message
    init(right: EqualValueConstraint, twa: Bool, initialAlpha: Double, initialValue: Double, initialWeight: ResultWeight) {
        self.right = right
        
        self.alpha = initialAlpha
        weights = twa ? TWAWeightData() : ADMMWeightData()
        
        reset(initialValue, initialWeight)
    }
    
    /// Reset the edge
    /// - Parameters:
    ///   - initialZ: initial value
    ///   - initialWeight: initial weight
    func reset(_ initialZ: Double, _ initialWeight: ResultWeight) {
        enabled = true
        
        x = 0.0
        u = 0.0
        z = initialZ
        
        weights.weightToLeft = initialWeight
        weights.weightToRight = .zero
        
        dir = .left
        
        oldMsg = nil
        msgDiff = nil
    }
    
    /// Enable the edge
    func enable() {
        reset(right.value, .std)
        right.forceEdgeRefresh()
    }
    
    /// Disable the edge
    func disable() {
        enabled = false
        right.forceEdgeRefresh()
    }
    
    /// Prepare the edge for factor-side processing
    func pointLeft() {
        dir = .left
        
        if weights.weightToLeft == .inf {
            u = 0.0
        } else {
            u += alpha * (x - z)
        }
    }
    
    /// Prepare the edge for variable-side processing
    func pointRight() {
        if let oldMsg = oldMsg {
            msgDiff = abs(msg - oldMsg)
        }
        oldMsg = msg
        
        dir = .right
        
        if weights.weightToRight == .inf {
            u = 0.0
        }
    }
    
    /// Computes the message to the right
    private var m: Double {
        return x + u
    }
    
    /// Computes the message to the left
    private var n: Double {
        return z - u
    }
    
    // *********************************************
    
    /// Current message
    public var msg: Double {
        switch dir {
            
        case .left:
            return n
        case .right:
            return m
        }
    }
    
    /// Weight of the current message
    public var weight: ResultWeight {
        switch dir {

        case .left:
            return weights.weightToLeft
        case .right:
            return weights.weightToRight
        }
    }
    
    /// Sets the current value and weight
    ///
    /// - Parameters:
    ///   - val: value to set
    ///   - weight: weight of the message to set
    public func setResult(_ val: Double, weight: ResultWeight = .std) {
        switch dir {
            
        case .left:
            x = val
            weights.weightToRight = weight
            
        case .right:
            z = val
            weights.weightToLeft = weight
        }
    }
}
