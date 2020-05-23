import Foundation

/// Given an array, produce a function that operates on each element of that array
typealias ArrayForWorker<T> = (Array<T>) -> ((T) -> Void) -> Void

extension Array {
    /// Produce concurrent for-loop for an array
    ///
    /// - Parameter work: operation to perform on each element
    func concurrentFor(work: (Element) -> Void) {
        self.withUnsafeBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { index in
                work(buffer[index])
            }
        }
    }
    
    /// Produce serial for-loop for an array
    ///
    /// - Parameter work: operation to perform on each element
    func serialFor(work: (Element) -> Void) {
        self.withUnsafeBufferPointer { buffer in
            for item in buffer {
                work(item)
            }
        }
    }
    
    /// Produces a generic for-loop function to apply to an array
    ///
    /// - Parameter concurrent: if true, the function operates concurrently; else serially
    /// - Returns: for-loop function for the array
    func getForWorker(_ concurrent: Bool) -> ArrayForWorker<Element> {
        return concurrent ? Array<Element>.concurrentFor : Array<Element>.serialFor
    }
}

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
