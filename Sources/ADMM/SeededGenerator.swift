import GameKit

/// An RNG that can be seeded
@available(OSX 10.11, *)
@available(iOS 9.0, *)
public class SeededGenerator: RandomNumberGenerator {
    /// Initial random seed for this RNG
    public let seed: UInt64
    
    /// Produced RNG
    private let generator: GKMersenneTwisterRandomSource
    
    /// Create the RNG without a seed 
    public convenience init() {
        self.init(seed: 0)
    }
    
    /// Create the RNG with a supplied seed
    ///
    /// - Parameter seed: RNG seed
    public init(seed: UInt64) {
        self.seed = seed
        generator = GKMersenneTwisterRandomSource(seed: seed)
    }
    
    /// Produces a random value
    ///
    /// - Returns: random value
    public func next() -> UInt64 {
        // GKRandom produces values in [INT32_MIN, INT32_MAX] range; hence we need two numbers to produce 64-bit value.
        let next1 = UInt64(bitPattern: Int64(generator.nextInt()))
        let next2 = UInt64(bitPattern: Int64(generator.nextInt()))
        return next1 ^ (next2 << 32)
    }
}

@available(OSX 10.11, *)
@available(iOS 9.0, *)
public extension UInt64 {
    /// Produces an RNG using the integer value as the seed
    func rng() -> SeededGenerator {
        return SeededGenerator(seed: self)
    }
}
