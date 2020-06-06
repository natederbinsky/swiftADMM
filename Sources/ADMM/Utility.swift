import Foundation

public extension Int {
    /// Produces a range given an integer as an upper bound
    ///
    /// - Returns: [0, value]
    func upToIncluding() -> ClosedRange<Int> {
        return 0...self
    }
    
    /// Produces a range given an integer as an upper bound
    ///
    /// - Returns: [0, value)
    func upToExcluding() -> Range<Int> {
        return 0..<self
    }
}

/// Performs a known bad cast to crash
public func crash() {
    let one: Int = Int("b")!
    print(one)
}
