public class Sudoku {
    /// Adds variables and constraints for a supplied Sudoku
    /// puzzle to an existing objective
    ///
    /// - Parameters:
    ///   - objective: existing objective graph
    ///   - innerSide: the side of each inner square of the puzzle (e.g., 3 is standard)
    ///   - known: sparse representation of each *given* value; indexes are 0..<(innerSide^4), so 0-80 for standard; values are 0..<(innerSide^2), so 0-8 for standard
    ///
    /// - returns: binary variables for each location/value possibility; outer array is organized per location 0..<(innerSide^4), inner array is per possible value, 0..<(innerSide^2)
    public static func addToObjective(objective obj: ObjectiveGraph, innerSide: Int, known: [Int:Int]) -> ContiguousArray<ContiguousArray<VariableNode>> {
        let outerSide = innerSide * innerSide
        var vars = ContiguousArray<ContiguousArray<VariableNode>>()
        
        for i in 0..<(outerSide * outerSide) {
            let knownValue: Int
            let knownWeight: MessageWeight
            
            if let knownResult = known[i] {
                knownValue = knownResult
                knownWeight = .inf
            } else {
                knownValue = -1
                knownWeight = .std
            }
            
            let options = ContiguousArray<VariableNode>(outerSide.upToExcluding().map { obj.createVariable(initialValue: $0 == knownValue ? 1.0 : 0.0, initialWeight: knownWeight) })
            
            vars.append(options)
            
            let _ = createOneHotFactor(objective: obj, vars: options)
            if knownValue != -1 {
                let _ = createKnownValueFactor(objective: obj, variable: options[knownValue], value: 1.0)
            }
        }
        
        let rowColSquareRange = outerSide.upToExcluding()
        
        for i in rowColSquareRange {
            for val in rowColSquareRange {
                // i is row, $0 is col
                let rowValVars: [VariableNode] = rowColSquareRange.map { vars[ i*outerSide + $0 ][val] }
                
                // i is col, $0 is row
                let colValVars: [VariableNode] = rowColSquareRange.map { vars[ $0*outerSide + i ][val] }
                
                // i is square, $0 is within-square index
                let squareValVars: [VariableNode] = rowColSquareRange.map {
                    let squareRow = i / innerSide
                    let squareCol = i % innerSide
                    
                    let row = $0 / innerSide
                    let col = $0 % innerSide
                    
                    let varIndex = (((squareRow * innerSide) + row) * outerSide) + ((squareCol * innerSide) + col)
                    
                    return vars[varIndex][val]
                }
                
                let _ = createOneHotFactor(objective: obj, vars: rowValVars)
                let _ = createOneHotFactor(objective: obj, vars: colValVars)
                let _ = createOneHotFactor(objective: obj, vars: squareValVars)
            }
        }
        
        return vars
    }
    
    /// Extracts the state of solving a Sudoku puzzle, represented via
    /// the binary variables of the objective graph
    ///
    /// - Parameter objective: objective graph
    /// - Parameter variables: binary variables associated with the sudoku problem
    ///
    /// - returns: value at each cell of the Sudoku grid (0..<(innerSide^2))
    public static func extractState(objective obj: ObjectiveGraph, variables: ContiguousArray<ContiguousArray<VariableNode>>) -> [Int] {
        variables.withUnsafeBufferPointer { vBuffer in
            return vBuffer.map {
                var result = -1
                
                $0.withUnsafeBufferPointer { innerBuffer in
                    for (j, v) in innerBuffer.enumerated() {
                        if obj.getValueUnsafe(v) > 0.99 {
                            result = j
                        }
                    }
                }
                
                return result
            }
        }
    }
}
