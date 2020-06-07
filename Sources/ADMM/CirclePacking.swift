import Foundation

public class CirclePacking {
    /// Generates a list of circles (x, y, radius) based upon input criteria
    ///
    /// - Parameters:
    ///    - rngSeed: random seed (for reproducibility)
    ///    - radii: list of (radius, number) pairs that indicates how many of what size radius to produce
    ///    - rangeHorizontal: x-bounds (inclusive)
    ///    - rangeVertical: y-bounds (inclusive)
    ///
    /// - returns: list of circle locations (x, y) and size (radius)
    @available(iOS 9.0, *)
    @available(OSX 10.11, *)
    public static func generateCircles<S: Sequence>(rngSeed:UInt64, radii: S, rangeHorizontal: ClosedRange<Double>, rangeVertical: ClosedRange<Double>) -> [(x: Double, y: Double, radius: Double)] where S.Element == (Double, Int) {
        var rng = rngSeed.rng()
        var result = [(x: Double, y: Double, radius: Double)]()
        
        for (radius, num) in radii {
            for _ in 1...num {
                let x = Double.random(in: rangeHorizontal, using:&rng)
                let y = Double.random(in: rangeVertical, using:&rng)
                
                result.append((x: x, y: y, radius: radius))
            }
        }
        
        return result
    }
    
    /// Creates a factor that keeps a circle a precise distance
    /// from a point
    ///
    /// - Parameters:
    ///   - objective: existing objective graph
    ///   - varX: variable of the x-position of the circle
    ///   - varY: variable of the y-position of the circle
    ///   - centerX: x-position from which to keep a precise distance
    ///   - centerY: y-position from which to keep a precise distance
    ///   - exactDist: distance to maintain from (centerX, centerY)
    ///
    /// - returns: produced factor
    public static func createKissFactor(objective obj: ObjectiveGraph, varX: VariableNode, varY: VariableNode, centerX: Double, centerY: Double, exactDist: Double) -> FactorNode {
        let edges = [
            obj.createEdge(varX),
            obj.createEdge(varY)
        ]
        
        let f: MinimizationFunction = {
            weightedMessages in
            
            let (x,_) = weightedMessages[0].get()
            let (y,_) = weightedMessages[1].get()
            
            let dx = x - centerX
            let dy = y - centerY
            
            let d = hypot(dx, dy)
            let dd = exactDist - d
            
            if dd != 0.0 {
                let unitDx = dx / d
                let unitDy = dy / d
                
                weightedMessages[0].set((value: centerX + exactDist*unitDx, weight: .std))
                weightedMessages[1].set((value: centerY + exactDist*unitDy, weight: .std))
            } else {
                weightedMessages[0].set((value: x, weight: .zero))
                weightedMessages[1].set((value: y, weight: .zero))
            }
        }
        
        return obj.createFactor(edges: edges, f)
    }

    /// Creates a factor that prevents two circles from intersecting
    ///
    /// - Parameters:
    ///   - objective: existing objective graph
    ///   - varX1: variable of the x-position of the first circle
    ///   - varY1: variable of the y-position of the first circle
    ///   - varX2: variable of the x-position of the second circle
    ///   - varY2: variable of the y-position of the second circle
    ///   - sumRadius: sum of the radii of the circles
    ///
    /// - returns: produced factor
    public static func createIntersectionFactor(objective obj: ObjectiveGraph, varX1: VariableNode, varY1: VariableNode, varX2: VariableNode, varY2: VariableNode, sumRadius: Double) -> FactorNode {
        let edges = [
            obj.createEdge(varX1),
            obj.createEdge(varY1),
            obj.createEdge(varX2),
            obj.createEdge(varY2)
        ]
        
        let f: MinimizationFunction = {
            weightedMessages in
            
            let (x1, _) = weightedMessages[0].get()
            let (y1, _) = weightedMessages[1].get()
            let (x2, _) = weightedMessages[2].get()
            let (y2, _) = weightedMessages[3].get()

            let dx = x2 - x1
            let dy = y2 - y1

            let d = hypot(dx, dy)
            let dd = sumRadius - d

            if dd < 0 {
                weightedMessages[0].set((value:x1, weight:.zero))
                weightedMessages[1].set((value:y1, weight:.zero))
                weightedMessages[2].set((value:x2, weight:.zero))
                weightedMessages[3].set((value:y2, weight:.zero))
                
            } else {
                let unitDx = dx / d
                let unitDy = dy / d
                let halfDD = dd / 2.0

                let moveX = halfDD*unitDx
                let moveY = halfDD*unitDy
                
                weightedMessages[0].set((value:x1 - moveX, weight:.std))
                weightedMessages[1].set((value:y1 - moveY, weight:.std))
                weightedMessages[2].set((value:x2 + moveX, weight:.std))
                weightedMessages[3].set((value:y2 + moveY, weight:.std))
            }
        }
        
        return obj.createFactor(edges: edges, f)
    }
    
    /// Adds variables and constraints for a supplied circle-packing
    /// problem to an existing objective
    ///
    /// - Parameters:
    ///    - objective: existing objective graph
    ///    - circles: list of (x,y) locations and radii of circles to pack
    ///    - rangeHorizontal: horizontal bounds of packing rectangle
    ///    - rangeVertical: vertical bounds of packing rectangle
    ///    - kissing: optionally an (x,y) location and distance to maintain for all circles
    ///
    /// - returns: (x-position variables, y-position variables, radii, intersection factors)
    ///
    /// - Note: intersection factors are indexed by lower circle index; each row gets shorter by one
    public static func addToObjective(objective obj: ObjectiveGraph, circles: [(x: Double, y: Double, radius: Double)], rangeHorizontal: ClosedRange<Double>, rangeVertical: ClosedRange<Double>, kissing: (x: Double, y: Double, radius: Double)?) -> (variablesX: ContiguousArray<VariableNode>, variablesY: ContiguousArray<VariableNode>, paramsRadius: ContiguousArray<Double>, intMinimizers: ContiguousArray<ContiguousArray<FactorNode>>) {
        var variablesX = ContiguousArray<VariableNode>()
        var variablesY = ContiguousArray<VariableNode>()
        var intMinimizers = ContiguousArray<ContiguousArray<FactorNode>>()
        var paramsRadius = ContiguousArray<Double>()
        
        for (x, y, radius) in circles {
            let varX = obj.createVariable(initialValue: x, initialWeight: .std)
            let varY = obj.createVariable(initialValue: y, initialWeight: .std)
            
            variablesX.append(varX)
            variablesY.append(varY)
            paramsRadius.append(radius)
            
            //
            
            let leftX = rangeHorizontal.lowerBound + radius
            let rightX = rangeHorizontal.upperBound - radius
            let topY = rangeVertical.lowerBound + radius
            let bottomY = rangeVertical.upperBound - radius
            
            let _ = createInRangeFactor(objective: obj, variable: varX, range: leftX...rightX)
            let _ = createInRangeFactor(objective: obj, variable: varY, range: topY...bottomY)
        }
        
        for i1 in 0..<(circles.count-1) {
            let varX1 = variablesX[i1]
            let varY1 = variablesY[i1]
            let r1 = paramsRadius[i1]
            
            var myMinimizers = ContiguousArray<FactorNode>()
            
            for i2 in i1+1..<circles.count {
                let varX2 = variablesX[i2]
                let varY2 = variablesY[i2]
                let r2 = paramsRadius[i2]
                
                let im = createIntersectionFactor(objective: obj, varX1: varX1, varY1: varY1, varX2: varX2, varY2: varY2, sumRadius: r1+r2)
                myMinimizers.append(im)
            }
            
            intMinimizers.append(myMinimizers)
        }
        
        if let kiss = kissing {
            for i in 0..<circles.count {
                let varX = variablesX[i]
                let varY = variablesY[i]
                let radius = paramsRadius[i]
                
                let _ = createKissFactor(objective: obj, varX: varX, varY: varY, centerX: kiss.x, centerY: kiss.y, exactDist: kiss.radius+radius)
            }
        }
        
        return (variablesX: variablesX, variablesY: variablesY, paramsRadius: paramsRadius, intMinimizers: intMinimizers)
    }
}
