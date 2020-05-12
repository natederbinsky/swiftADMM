import XCTest

@testable import ADMM

final class ADMMTests: XCTestCase {
    func testWeightsADMM() {
        var testWeight = ADMMWeightData()
        
        testWeight.weightToLeft = Double.zero
        testWeight.weightToRight = Double.zero
        
        XCTAssertEqual(testWeight.weightToLeft, Edge.STANDARD)
        XCTAssertEqual(testWeight.weightToRight, Edge.STANDARD)
        
        testWeight.weightToLeft = Double.infinity
        testWeight.weightToRight = Double.infinity
        
        XCTAssertEqual(testWeight.weightToLeft, Edge.STANDARD)
        XCTAssertEqual(testWeight.weightToRight, Edge.STANDARD)
        
        testWeight.weightToLeft = Edge.STANDARD
        testWeight.weightToRight = Edge.STANDARD
        
        XCTAssertEqual(testWeight.weightToLeft, Edge.STANDARD)
        XCTAssertEqual(testWeight.weightToRight, Edge.STANDARD)
    }
    
    func testWeightsTWA() {
        var testWeight = TWAWeightData()
        
        testWeight.weightToLeft = Double.zero
        testWeight.weightToRight = Double.zero
        
        XCTAssert(testWeight.weightToLeft.isZero)
        XCTAssert(testWeight.weightToRight.isZero)
        
        testWeight.weightToLeft = Double.infinity
        testWeight.weightToRight = Double.infinity
        
        XCTAssert(testWeight.weightToLeft.isInfinite)
        XCTAssert(testWeight.weightToRight.isInfinite)
        
        testWeight.weightToLeft = Edge.STANDARD
        testWeight.weightToRight = Edge.STANDARD
        
        XCTAssertEqual(testWeight.weightToLeft, Edge.STANDARD)
        XCTAssertEqual(testWeight.weightToRight, Edge.STANDARD)
    }
    
    func testMessages() {
        let testEdge = Edge(initialValue: 5.0, initialWeight: .std, twa: false, alpha: 0.1)
        
        XCTAssertEqual(testEdge.z, 5.0)
        XCTAssertEqual(testEdge.msg, 5.0)
        
        testEdge.setResult(3.0)
        
        XCTAssertEqual(testEdge.z, 5.0)
        XCTAssertEqual(testEdge.msg, 5.0)
        
        testEdge.pointRight()
        
        XCTAssertEqual(testEdge.z, 5.0)
        XCTAssertEqual(testEdge.msg, 3.0)
        
        testEdge.setResult(10.0)
        
        XCTAssertEqual(testEdge.z, 10.0)
        XCTAssertEqual(testEdge.msg, 3.0)
        
        testEdge.pointLeft()
        
        XCTAssertEqual(testEdge.z, 10.0)
        XCTAssertEqual(testEdge.msg, 10.7, accuracy: 1e-10)
        
        testEdge.setResult(3.0)
        
        XCTAssertEqual(testEdge.z, 10.0)
        XCTAssertEqual(testEdge.msg, 10.7, accuracy: 1e-10)
        
        testEdge.pointRight()
        
        XCTAssertEqual(testEdge.z, 10.0)
        XCTAssertEqual(testEdge.msg, 2.3, accuracy: 1e-10)
    }

    static var allTests = [
        ("testExample", testWeightsADMM),
        ("testWeightsTWA", testWeightsTWA),
        ("testMessages", testMessages),
    ]
}
