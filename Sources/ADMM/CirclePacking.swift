import GameKit

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
    
    private static func _newMax(old: Double?, new: Double) -> Double {
        var contender = new
        if new < 0 {
            contender = 0.0
        }
        
        if let maxSoFar = old {
            if contender > maxSoFar {
                return contender
            } else {
                return maxSoFar
            }
        } else {
            return contender
        }
    }
    
    /// Computes the maximum constraint violation (boundary or intersection)
    ///
    /// - Parameters:
    ///   - objective: objective graph
    ///   - varsX: x-coordinate variables
    ///   - varsY: y-coordinate variables
    ///   - radii: radii of each circle
    ///   - horizRange: legal horizontal span
    ///   - vertRange: legal vertical span
    ///
    /// - returns: maximum overlap of any circle (min value is 0)
    public static func maxOverlap(objective obj: ObjectiveGraph, varsX: ContiguousArray<VariableNode>, varsY: ContiguousArray<VariableNode>, radii: ContiguousArray<Double>, horizRange: ClosedRange<Double>, vertRange: ClosedRange<Double>) -> Double {
        let circles = (0..<varsX.count).map { i in
            (x: obj[varsX[i]], y: obj[varsY[i]], r: radii[i])
        }
        
        var maxOverlap: Double? = nil
        
        for c in circles {
            maxOverlap = _newMax(old: maxOverlap, new: horizRange.lowerBound - (c.x - c.r))
            maxOverlap = _newMax(old: maxOverlap, new: (c.x + c.r) - horizRange.upperBound)
            maxOverlap = _newMax(old: maxOverlap, new: vertRange.lowerBound - (c.y - c.r))
            maxOverlap = _newMax(old: maxOverlap, new: (c.y + c.r) - vertRange.upperBound)
        }
        
        for i1 in 0..<(circles.count - 1) {
            let c1 = circles[i1]
            
            for i2 in (i1+1)..<circles.count {
                let c2 = circles[i2]
                
                let xDiff = (c1.x - c2.x)
                let yDiff = (c1.y - c2.y)
                let dist = sqrt(xDiff*xDiff + yDiff*yDiff)
                
                let sumRadii = c1.r + c2.r
                
                let overlap = sumRadii - dist
                
                maxOverlap = _newMax(old: maxOverlap, new: overlap)
            }
        }
        
        return maxOverlap!
    }
    
    @available(iOS 10.0, *)
    @available(OSX 10.12, *)
    public static func addToObjectiveFast(objective obj: ObjectiveGraph, circles: [(x: Double, y: Double, radius: Double)], rangeHorizontal: ClosedRange<Double>, rangeVertical: ClosedRange<Double>) -> (variablesX: ContiguousArray<VariableNode>, variablesY: ContiguousArray<VariableNode>, paramsRadius: ContiguousArray<Double>, intMinimizers: ContiguousArray<ContiguousArray<FactorNode>>) {
        let result = addToObjective(objective: obj, circles: circles, rangeHorizontal: rangeHorizontal, rangeVertical: rangeVertical, kissing: nil)
        
        let _ = FastCirclePackingGraphManager(horizRange: rangeHorizontal, vertRange: rangeVertical, numCells: circles.count / 10, maxRadius: 1.4 * result.paramsRadius.max()!, obj: obj, variablesX: result.variablesX, variablesY: result.variablesY, intFactors: result.intMinimizers, paramsRadius: result.paramsRadius)
        
        return result
    }
}

/// Uses a spatial data structure to dynamically enable/disable intersection
/// factors in a circle-packing problem
@available(iOS 10.0, *)
@available(OSX 10.12, *)
fileprivate class FastCirclePackingGraphManager {
    private let quadtree: DeltaQuadTree
    
    private let obj: ObjectiveGraph
    private let variablesX: ContiguousArray<VariableNode>
    private let variablesY: ContiguousArray<VariableNode>
    private let intFactors: ContiguousArray<ContiguousArray<FactorNode>>
    
    init(horizRange: ClosedRange<Double>, vertRange: ClosedRange<Double>, numCells: Int, maxRadius: Double, obj: ObjectiveGraph, variablesX: ContiguousArray<VariableNode>, variablesY: ContiguousArray<VariableNode>, intFactors: ContiguousArray<ContiguousArray<FactorNode>>, paramsRadius: ContiguousArray<Double>) {
        quadtree = DeltaQuadTree(horizRange: horizRange, vertRange: vertRange, numCells: numCells, maxRadius: maxRadius)
        
        self.obj = obj
        self.variablesX = variablesX
        self.variablesY = variablesY
        self.intFactors = intFactors
        
        /// Add objects to the spatial data structure
        for i in variablesX.count.upToExcluding() {
            quadtree.addObject(halfWidth: paramsRadius[i], x: obj[variablesX[i]], y: obj[variablesY[i]])
        }
        
        /// Disable all intersection factors
        disableIntersections()
        
        /// Add back only those that are needed
        updateLocations()
        
        /// When the objective graph is re-initialized
        /// so too should internal data structures
        obj.addReinitCallback {
            self.reinit()
        }
        
        /// When an iteration occurs, update the
        /// spatial data structure and enable/disable
        /// associated factors
        obj.addIterationCallback {
            self.updateLocations()
        }
    }
    
    private func reinit() {
        quadtree.reinit()
        disableIntersections()
        updateLocations()
    }
    
    private func updateLocations() {
        variablesX.withUnsafeBufferPointer { vXBuffer in
            variablesY.withUnsafeBufferPointer { vYBuffer in
                quadtree.moveAll {
                    index in
                    
                    return (obj.getValueUnsafe(vXBuffer[index]), obj.getValueUnsafe(vYBuffer[index]))
                }
                updateIntersections()
            }
        }
    }
    
    //
    
    private func disableIntersections() {
        intFactors.withUnsafeBufferPointer { imBuffer in
            for ms in imBuffer {
                ms.withUnsafeBufferPointer { msBuffer in
                    for m in msBuffer {
                        obj[m] = false
                    }
                }
            }
        }
    }
    
    private func updateIntersections() {
        intFactors.withUnsafeBufferPointer { imBuffer in
            quadtree.updateAll {
                id, toAdd, toRemove in
                
                toAdd.withUnsafeBufferPointer { addBuffer in
                    for idNode in addBuffer {
                        updatePair(imBuffer, id1: id, id2: idNode.id, isEnabled: true)
                    }
                }
                
                toRemove.withUnsafeBufferPointer { removeBuffer in
                    for idNode in removeBuffer {
                        updatePair(imBuffer, id1: id, id2: idNode.id, isEnabled: false)
                    }
                }
            }
        }
    }
    
    private func updatePair(_ imBuffer: UnsafeBufferPointer<ContiguousArray<FactorNode>>, id1: Int, id2: Int, isEnabled: Bool) {
        let s = min(id1, id2)
        let l = max(id1, id2)
        
        imBuffer[s].withUnsafeBufferPointer { sBuffer in
            obj[sBuffer[l - s - 1]] = isEnabled
        }
    }
}

/// 2-D object with coordinates and an ID
@available(iOS 10.0, *)
@available(OSX 10.12, *)
fileprivate class IDNode2D: NSObject {
    let id: Int
    let halfWidth: Float
    
    var x: Float = 0.0
    var y: Float = 0.0
    
    override var description: String {
        "\(id) @ (\(x), \(y))"
    }
    
    init(id: Int, halfWidth: Float) {
        self.id = id
        self.halfWidth = halfWidth
    }
}

/// Spatial data structure that can operate on
/// discrete changes (adds/removes) of nearby
/// objects
@available(iOS 10.0, *)
@available(OSX 10.12, *)
fileprivate class DeltaQuadTree {
    private let tree: GKQuadtree<IDNode2D>
    private let widthToAdd: Float
    
    private var idNodes = ContiguousArray<IDNode2D>()
    private var treeNodes = ContiguousArray<GKQuadtreeNode>()
    private var nearby = ContiguousArray<ContiguousArray<IDNode2D>>()
    
    //
    
    init(horizRange: ClosedRange<Double>, vertRange: ClosedRange<Double>, numCells: Int, maxRadius: Double) {
        let hDiff = Float(horizRange.upperBound - horizRange.lowerBound)
        let vDiff = Float(vertRange.upperBound - vertRange.lowerBound)
        let buffer = Float(0.1)
        
        tree = GKQuadtree<IDNode2D>(boundingQuad: GKQuad(quadMin: [Float(horizRange.lowerBound) - buffer*hDiff, Float(vertRange.lowerBound) - buffer*vDiff], quadMax: [Float(horizRange.upperBound) + buffer*hDiff, Float(vertRange.upperBound) + buffer*vDiff]), minimumCellSize: (hDiff * vDiff) / Float(numCells))
        
        widthToAdd = Float(maxRadius)
    }
    
    func reinit() {
        nearby = ContiguousArray<ContiguousArray<IDNode2D>>(idNodes.map {
            _ in
            ContiguousArray<IDNode2D>()
        })
    }
    
    func addObject(halfWidth: Double, x: Double, y: Double) {
        let idNode = IDNode2D(id: idNodes.count, halfWidth: Float(halfWidth))
        
        idNode.x = Float(x)
        idNode.y = Float(y)
        
        idNodes.append(idNode)
        treeNodes.append(tree.add(idNode, at: [Float(x), Float(y)]))
        nearby.append(ContiguousArray<IDNode2D>())
    }
    
    func move(id: Int, x newX: Double, y newY: Double) {
        move(idNode: idNodes[id], x: newX, y: newY)
    }
    
    func move(idNode: IDNode2D, x newX: Double, y newY: Double) {
        let newX = Float(newX)
        let newY = Float(newY)
        
        if (idNode.x != newX) || (idNode.y != newY) {
            let id = idNode.id
            
            treeNodes.withUnsafeMutableBufferPointer { treeBuffer in
                tree.remove(idNode, using: treeBuffer[id])
                
                idNode.x = newX
                idNode.y = newY
                treeBuffer[id] = tree.add(idNode, at: [newX, newY])
            }
        }
    }
    
    func moveAll(_ f: (Int) -> (Double, Double)) {
        idNodes.withUnsafeBufferPointer { idBuffer in
            for idNode in idBuffer {
                let loc = f(idNode.id)
                
                move(idNode: idNode, x: loc.0, y: loc.1)
            }
        }
    }
    
    func updateNearby(_ id: Int) -> (add: ContiguousArray<IDNode2D>, remove: ContiguousArray<IDNode2D>) {
        return updateNearby(idNodes[id])
    }
    
    func updateNearby(_ idNode: IDNode2D) -> (add: ContiguousArray<IDNode2D>, remove: ContiguousArray<IDNode2D>) {
        let searchDist = idNode.halfWidth + widthToAdd
        
        let oldNearby = nearby[idNode.id]
        
        //
        
        let allNearby = tree.elements(in: GKQuad(quadMin: [idNode.x-searchDist, idNode.y-searchDist], quadMax: [idNode.x+searchDist, idNode.y+searchDist]))
        
        var newNearby = ContiguousArray<IDNode2D>()
        newNearby.reserveCapacity(allNearby.count - 1)
        
        var toAdd = ContiguousArray<IDNode2D>()
        var toRemove = ContiguousArray<IDNode2D>()
        
        oldNearby.withUnsafeBufferPointer { oldBuffer in
            for nearbyNode in allNearby {
                if nearbyNode != idNode {
                    newNearby.append(nearbyNode)
                    
                    if !oldBuffer.contains(nearbyNode) {
                        toAdd.append(nearbyNode)
                    }
                }
            }
            
            newNearby.withUnsafeBufferPointer { newBuffer in
                for removeCandidate in oldBuffer {
                    if !newBuffer.contains(removeCandidate) {
                        toRemove.append(removeCandidate)
                    }
                }
            }
        }
        
        nearby[idNode.id] = newNearby
        
        return (add: toAdd, remove: toRemove)
    }
    
    func updateAll(_ f: (Int, ContiguousArray<IDNode2D>, ContiguousArray<IDNode2D>) -> Void) {
        idNodes.withUnsafeBufferPointer { idBuffer in
            for idNode in idBuffer {
                let updateResult = updateNearby(idNode)
                
                f(idNode.id, updateResult.add, updateResult.remove)
            }
        }
    }
}
