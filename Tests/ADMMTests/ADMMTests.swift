import XCTest

import ADMM

@available(iOS 10.0, *)
@available(OSX 10.12, *)
final class ADMMTests: XCTestCase {
    private static func _reportFindings(_ obj: ObjectiveGraph, _ numIterations: Int, _ description: String) {
        XCTAssertEqual(0, obj.iterations)
        XCTAssertFalse(obj.converged)
        
        let start = Date()
        for _ in 1...numIterations {
            let _ = obj.iterate()
        }
        let end = Date()
        let diff = end.timeIntervalSince(start)
        
        let timePerIteration = 1000.0 * diff / Double(numIterations)
        let timePerIterationEdge = 1000.0 * diff / (Double(numIterations * obj.numEnabledEdges))
        print("\(description): \(String(format: "%.2f ms/iteration", timePerIteration)), \(String(format: "%.2e ms/iteration-edge", timePerIterationEdge))")
        
        XCTAssertFalse(obj.converged)
        obj.reinitialize()
    }
    
    //
    
    private func _sudokuPerformance(algorithm: Algorithm, concurrent: Bool) -> (ObjectiveGraph, ContiguousArray<ContiguousArray<VariableNode>>, [Int]) {
        let obj = ObjectiveGraph(algorithm: algorithm, learningRate: 1.0, concurrent: concurrent)
        
        // source: https://www.menneske.no/sudoku/eng/
        let given = [62: 5, 130: 6, 91: 8, 2: 4, 114: 0, 222: 2, 139: 7, 39: 5, 102: 2, 60: 0,
                     188: 10, 148: 2, 42: 15, 224: 13, 28: 1, 119: 6, 85: 14, 135: 4, 170: 8,
                     158: 7, 146: 5, 58: 7, 181: 0, 36: 7, 180: 15, 33: 10, 107: 9, 253: 10,
                     125: 2, 141: 8, 252: 6, 178: 9, 97: 4, 216: 6, 74: 12, 128: 0, 213: 8,
                     152: 9, 75: 15, 183: 8, 199: 2, 77: 14, 240: 9, 116: 4, 113: 1, 194: 1,
                     173: 0, 31: 13, 248: 12, 112: 12, 164: 12, 101: 15, 67: 5, 88: 0, 43: 1,
                     246: 3, 238: 0, 7: 3, 232: 11, 196: 6, 103: 13, 138: 10, 195: 14, 153: 0,
                     6: 12, 72: 3, 1: 5, 212: 0, 117: 3, 166: 11, 250: 0, 82: 10, 193: 0,
                     120: 14, 197: 9, 254: 13, 227: 7, 109: 11, 3: 9, 23: 0, 15: 14, 154: 14,
                     61: 15, 17: 11, 59: 14, 219: 3, 136: 13, 5: 11, 142: 15, 89: 6, 127: 8,
                     9: 13, 56: 2, 44: 3, 143: 9, 249: 15, 167: 9, 211: 10]
        
        let solution = [15, 5, 4, 9, 1, 11, 12, 3, 10, 13, 6, 0, 2, 7, 8, 14, 8, 11, 7, 2, 14, 6, 15,
                        0, 5, 3, 4, 12, 1, 9, 10, 13, 14, 10, 13, 0, 7, 2, 9, 5, 8, 11, 15, 1, 3, 6,
                        4, 12, 1, 3, 12, 6, 13, 4, 8, 10, 2, 9, 7, 14, 0, 15, 5, 11, 2, 9, 8, 5, 11,
                        1, 0, 7, 3, 4, 12, 15, 13, 14, 6, 10, 7, 13, 10, 11, 9, 14, 5, 12, 0, 6, 2,
                        8, 15, 1, 3, 4, 6, 4, 14, 3, 8, 15, 2, 13, 1, 10, 5, 9, 7, 11, 12, 0, 12, 1,
                        0, 15, 4, 3, 10, 6, 14, 7, 11, 13, 5, 2, 9, 8, 0, 2, 6, 12, 3, 5, 14, 4, 13,
                        1, 10, 7, 11, 8, 15, 9, 4, 15, 5, 8, 2, 10, 6, 1, 9, 0, 14, 11, 12, 13, 7, 3,
                        10, 7, 3, 1, 12, 13, 11, 9, 15, 2, 8, 5, 4, 0, 14, 6, 11, 14, 9, 13, 15, 0, 7,
                        8, 4, 12, 3, 6, 10, 5, 1, 2, 3, 0, 1, 14, 6, 9, 4, 2, 7, 5, 13, 10, 8, 12, 11,
                        15, 5, 12, 15, 10, 0, 8, 13, 11, 6, 14, 1, 3, 9, 4, 2, 7, 13, 6, 2, 7, 10, 12,
                        1, 15, 11, 8, 9, 4, 14, 3, 0, 5, 9, 8, 11, 4, 5, 7, 3, 14, 12, 15, 0, 2, 6, 10,
                        13, 1]
        
        let variables = Sudoku.addToObjective(objective: obj, innerSide: 4, known: given)
        
        return (obj, variables, solution)
    }
    
    func testSudoku0a_ADMMSerialPerformance() throws {
        let (obj, _, _) = _sudokuPerformance(algorithm: .admm, concurrent: false)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Sudoku (ADMM, Serial)")
        }
    }
    
    func testSudoku0b_ADMMConcurrentPerformance() throws {
        let (obj, _, _) = _sudokuPerformance(algorithm: .admm, concurrent: true)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Sudoku (ADMM, Concurrent)")
        }
    }
    
    func testSudoku1a_TWASerialPerformance() throws {
        let (obj, _, _) = _sudokuPerformance(algorithm: .twa, concurrent: false)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Sudoku (TWA, Serial)")
        }
    }
    
    func testSudoku1b_TWAConcurrentPerformance() throws {
        let (obj, _, _) = _sudokuPerformance(algorithm: .twa, concurrent: true)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Sudoku (TWA, Concurrent)")
        }
    }
    
    func testSudoku2a_ADMMConverged() throws {
        let (obj, variables, solution) = _sudokuPerformance(algorithm: .admm, concurrent: true)
        
        XCTAssertEqual(0, obj.iterations)
        XCTAssertFalse(obj.converged)
        
        for _ in 1...2 {
            for _ in 1...2000 {
                let _ = obj.iterate()
            }
            XCTAssertTrue(obj.converged)
            XCTAssertEqual(Sudoku.extractState(objective: obj, variables: variables), solution)
            // print(obj.iterations) // 1052
            obj.reinitialize()
        }
    }
    
    func testSudoku2b_TWAConverged() throws {
        let (obj, variables, solution) = _sudokuPerformance(algorithm: .twa, concurrent: true)
        
        XCTAssertEqual(0, obj.iterations)
        XCTAssertFalse(obj.converged)
        
        for _ in 1...2 {
            for _ in 1...2000 {
                let _ = obj.iterate()
            }
            XCTAssertTrue(obj.converged)
            XCTAssertEqual(Sudoku.extractState(objective: obj, variables: variables), solution)
            // print(obj.iterations) // 168
            obj.reinitialize()
        }
    }
    
    //

    private func _packingPerformance(algorithm: Algorithm, concurrent: Bool) -> (ObjectiveGraph, ContiguousArray<VariableNode>, ContiguousArray<VariableNode>, ContiguousArray<Double>, Double, ClosedRange<Double>, ClosedRange<Double>) {
        let convergenceDelta = 1e-5
        let obj = ObjectiveGraph(algorithm: algorithm, learningRate: 0.07, convergenceDelta: convergenceDelta, concurrent: concurrent)
        
        let range = 0...1.0
        
        // density: 0.8
        let circles = CirclePacking.generateCircles(rngSeed: 777, radii: [(0.050462650440403205, 100)], rangeHorizontal: range, rangeVertical: range)
        
        let added = CirclePacking.addToObjective(objective: obj, circles: circles, rangeHorizontal: range, rangeVertical: range, kissing: nil)
        
        return (obj, added.variablesX, added.variablesY, added.paramsRadius, convergenceDelta, range, range)
    }
    
    private func _packingPerformanceFast(algorithm: Algorithm, concurrent: Bool) -> (ObjectiveGraph, ContiguousArray<VariableNode>, ContiguousArray<VariableNode>, ContiguousArray<Double>, Double, ClosedRange<Double>, ClosedRange<Double>) {
        let convergenceDelta = 1e-4
        let obj = ObjectiveGraph(algorithm: algorithm, learningRate: 0.07, convergenceDelta: convergenceDelta, concurrent: concurrent)
        
        let range = 0...1.0
        
        // density: 0.8592
        let circles = CirclePacking.generateCircles(rngSeed: 778, radii: [(0.016604139052614, 992)], rangeHorizontal: range, rangeVertical: range)
        
        let added = CirclePacking.addToObjectiveFast(objective: obj, circles: circles, rangeHorizontal: range, rangeVertical: range)
        
        return (obj, added.variablesX, added.variablesY, added.paramsRadius, convergenceDelta, range, range)
    }
    
    func testCirclePacking0a_ADMMSerialPerformance() throws {
        let (obj, _, _, _, _, _, _) = _packingPerformance(algorithm: .admm, concurrent: false)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Circle Packing (ADMM, Serial)")
        }
    }
    
    func testCirclePacking0b_ADMMConcurrentPerformance() throws {
        let (obj, _, _, _, _, _, _) = _packingPerformance(algorithm: .admm, concurrent: true)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Circle Packing (ADMM, Concurrent)")
        }
    }
    
    func testCirclePacking1a_TWASerialPerformance() throws {
        let (obj, _, _, _, _, _, _) = _packingPerformance(algorithm: .twa, concurrent: false)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Circle Packing (TWA, Serial)")
        }
    }
    
    func testCirclePacking1b_TWAConcurrentPerformance() throws {
        let (obj, _, _, _, _, _, _) = _packingPerformance(algorithm: .twa, concurrent: true)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Circle Packing (TWA, Concurrent)")
        }
    }
    
    func testCirclePacking1c_TWASerialPerformanceFast() throws {
        let (obj, _, _, _, _, _, _) = _packingPerformanceFast(algorithm: .twa, concurrent: false)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Fast Circle Packing (TWA, Serial)")
        }
    }
    
    func testCirclePacking1d_TWAConcurrentPerformanceFast() throws {
        let (obj, _, _, _, _, _, _) = _packingPerformanceFast(algorithm: .twa, concurrent: true)
        
        measure {
            ADMMTests._reportFindings(obj, 30, "Fast Circle Packing (TWA, Concurrent)")
        }
    }
    
    func testCirclePacking2a_ADMMConverged() throws {
        let (obj, vX, vY, r, convD, rX, rY) = _packingPerformance(algorithm: .admm, concurrent: true)
        
        XCTAssertEqual(0, obj.iterations)
        XCTAssertFalse(obj.converged)
        
        for _ in 1...2 {
            for _ in 1...20000 {
                let _ = obj.iterate()
            }
            XCTAssertTrue(obj.converged)
            // print(obj.iterations) // 17202
            XCTAssertLessThan(CirclePacking.maxOverlap(objective: obj, varsX: vX, varsY: vY, radii: r, horizRange: rX, vertRange: rY), 100.0*convD)
            obj.reinitialize()
        }
    }
    
    func testCirclePacking2b_TWAConverged() throws {
        let (obj, vX, vY, r, convD, rX, rY) = _packingPerformance(algorithm: .twa, concurrent: true)
        
        XCTAssertEqual(0, obj.iterations)
        XCTAssertFalse(obj.converged)
        
        for _ in 1...2 {
            for _ in 1...1000 {
                let _ = obj.iterate()
            }
            XCTAssertTrue(obj.converged)
            // print(obj.iterations) // 892
            XCTAssertLessThan(CirclePacking.maxOverlap(objective: obj, varsX: vX, varsY: vY, radii: r, horizRange: rX, vertRange: rY), 100.0*convD)
            obj.reinitialize()
        }
    }
    
    func testCirclePacking2c_TWAFastConverged() throws {
        let (obj, vX, vY, r, convD, rX, rY) = _packingPerformanceFast(algorithm: .twa, concurrent: true)
        
        XCTAssertEqual(0, obj.iterations)
        XCTAssertFalse(obj.converged)
        
        for _ in 1...2 {
            for _ in 1...4000 {
                let _ = obj.iterate()
            }
            XCTAssertTrue(obj.converged)
            // print(obj.iterations) // 3458
            XCTAssertLessThan(CirclePacking.maxOverlap(objective: obj, varsX: vX, varsY: vY, radii: r, horizRange: rX, vertRange: rY), 100.0*convD)
            obj.reinitialize()
        }
    }
    
    //

    static var allTests = [
        ("testSudokuADMMSerialPerformance", testSudoku0a_ADMMSerialPerformance),
        ("testSudokuADMMConcurrentPerformance", testSudoku0b_ADMMConcurrentPerformance),
        ("testSudokuTWASerialPerformance", testSudoku1a_TWASerialPerformance),
        ("testSudokuTWAConcurrentPerformance", testSudoku1b_TWAConcurrentPerformance),
        ("testSudokuADMMConverged", testSudoku2a_ADMMConverged),
        ("testSudokuTWAConverged", testSudoku2b_TWAConverged),
        
        ("testCirclePackingADMMSerialPerformance", testCirclePacking0a_ADMMSerialPerformance),
        ("testCirclePackingADMMConcurrentPerformance", testCirclePacking0b_ADMMConcurrentPerformance),
        ("testCirclePackingTWASerialPerformance", testCirclePacking1a_TWASerialPerformance),
        ("testCirclePackingTWAConcurrentPerformance", testCirclePacking1b_TWAConcurrentPerformance),
        ("testCirclePackingTWASerialPerformanceFast", testCirclePacking1c_TWASerialPerformanceFast),
        ("testCirclePackingTWAConcurrentPerformanceFast", testCirclePacking1d_TWAConcurrentPerformanceFast),
        ("testCirclePackingADMMConverged", testCirclePacking2a_ADMMConverged),
        ("testCirclePackingTWAConverged", testCirclePacking2b_TWAConverged),
        ("testCirclePackingTWAFastConverged", testCirclePacking2c_TWAFastConverged),
    ]
}
