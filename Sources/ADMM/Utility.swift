import Foundation

// Allows objects to be used in sets/dictionaries
// via their address
class ObjectWrapper<T>: Equatable, Hashable {
    private let obj: T
    
    var wrapped: T { obj }
    
    init(_ obj: T) {
        self.obj = obj
    }
    
    static func == (lhs: ObjectWrapper, rhs: ObjectWrapper) -> Bool {
        return (lhs.obj as AnyObject) === (rhs.obj as AnyObject)
    }
    
    func hash(into hasher: inout Hasher) {
        // Use the instance's unique identifier for hashing
        hasher.combine(ObjectIdentifier(obj as AnyObject))
    }
}

//

typealias ArrayForWorker<T> = (Array<T>) -> ((T) -> Void) -> Void

// Concurrent/Serial for-loops for any array
extension Array {
    func concurrentFor(work: (Element) -> Void) {
        self.withUnsafeBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { index in
                work(buffer[index])
            }
        }
    }
    
    func serialFor(work: (Element) -> Void) {
        self.withUnsafeBufferPointer { buffer in
            for item in buffer {
                work(item)
            }
        }
    }
    
    func getForWorker(_ concurrent: Bool) -> ArrayForWorker<Element> {
        return concurrent ? Array<Element>.concurrentFor : Array<Element>.serialFor
    }
}

// Quick range-makers
public extension Int {
    func upToIncluding() -> ClosedRange<Int> {
        return 0...self
    }
    
    func upToExcluding() -> Range<Int> {
        return 0..<self
    }
}
