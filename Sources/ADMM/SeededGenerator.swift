import Foundation
import GameKit

@available(OSX 10.11, *)
@available(iOS 9.0, *)
public class SeededGenerator: RandomNumberGenerator {
    public let seed: UInt64
    private let generator: GKMersenneTwisterRandomSource
    
    public convenience init() {
        self.init(seed: 0)
    }
    
    public init(seed: UInt64) {
        self.seed = seed
        generator = GKMersenneTwisterRandomSource(seed: seed)
    }
    
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
    func rng() -> SeededGenerator {
        return SeededGenerator(seed: self)
    }
}
