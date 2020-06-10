// Example shell script that packs 4 circles in a 1x1 square
// using the swiftADMM library
// (https://github.com/natederbinsky/swiftADMM)
//
// XCode makes running straightforward, but there is also
// a Makefile for easy compilation/running
// 

import ADMM

// Create the graphical representation of the
// objective function (by default is concurrent)
let obj = ObjectiveGraph(algorithm: .twa, learningRate: 0.07)

// Problem parameters: 4 circles
// of radius 0.25 in a 1x1 square
let (circleRadii, numCircles) = (0.25, 4)
let range = 0...1.0

// Seed to produce random initial positions
let rngSeed: UInt64 = 4321

// Produce a list of initial circle
// locations and radii
let circles = CirclePacking.generateCircles(rngSeed: rngSeed, radii: [(circleRadii, numCircles)], rangeHorizontal: range, rangeVertical: range)

// Adds all variables, constraints, edges necessary to keep
// the circles in the square and not intersect
let vars = CirclePacking.addToObjective(objective: obj, circles: circles, rangeHorizontal: range, rangeVertical: range, kissing: nil)

// Outputs initial locations of the circles
for i in 0..<vars.variablesX.count {
    print("\(i): (\(obj[vars.variablesX[i]]), \(obj[vars.variablesY[i]]))")
}

// Attempts to solve for 100 iterations,
// or convergence, whichever happens first
for _ in 1...100 {
    if obj.iterate() {
        break
    }
}

// Output iterations/convergence
print("Iterations: \(obj.iterations)")
print("Converged? \(obj.converged)")

// Outputs final circle locations
for i in 0..<vars.variablesX.count {
    print("\(i): (\(obj[vars.variablesX[i]]), \(obj[vars.variablesY[i]]))")
}
