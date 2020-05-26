import XCTest

@testable import ADMM

final class ADMMTests: XCTestCase {
    func testWeightsADMM() {
        var testWeight = ADMMWeightData()
        
        testWeight.weightToLeft = .zero
        testWeight.weightToRight = .zero
        
        XCTAssertEqual(testWeight.weightToLeft, .std)
        XCTAssertEqual(testWeight.weightToRight, .std)
        
        testWeight.weightToLeft = .inf
        testWeight.weightToRight = .inf
        
        XCTAssertEqual(testWeight.weightToLeft, .std)
        XCTAssertEqual(testWeight.weightToRight, .std)
        
        testWeight.weightToLeft = .std
        testWeight.weightToRight = .std
        
        XCTAssertEqual(testWeight.weightToLeft, .std)
        XCTAssertEqual(testWeight.weightToRight, .std)
    }
    
    func testWeightsTWA() {
        var testWeight = TWAWeightData()
        
        testWeight.weightToLeft = .zero
        testWeight.weightToRight = .zero
        
        XCTAssertEqual(testWeight.weightToLeft, .zero)
        XCTAssertEqual(testWeight.weightToRight, .zero)
        
        testWeight.weightToLeft = .inf
        testWeight.weightToRight = .inf
        
        XCTAssertEqual(testWeight.weightToLeft, .inf)
        XCTAssertEqual(testWeight.weightToRight, .inf)
        
        testWeight.weightToLeft = .std
        testWeight.weightToRight = .std
        
        XCTAssertEqual(testWeight.weightToLeft, .std)
        XCTAssertEqual(testWeight.weightToRight, .std)
    }
    
    func testMessages() {
        let constraint = EqualValueConstraint(twa: false, initialZ: 5.0)
        let testEdge = Edge(right: constraint, twa: false, initialAlpha: 0.1, initialValue: 5.0, initialWeight: .std)
        
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
