private func _zero(_ weightedMessages: UnsafeMutableBufferPointer<WeightedValueExchange>, weight: MessageWeight) {
    for i in 0..<weightedMessages.count {
        weightedMessages[i].set((value: 0.0, weight: weight))
    }
}

public func createOneHotFactor<T: Sequence>(objective obj: ObjectiveGraph, vars: T) -> FactorNode where T.Element == VariableNode {
    let edges = vars.map { obj.createEdge($0) }
    let f: MinimizationFunction
    
    if obj.algorithm == .admm {
        f = {
            weightedMessages in
            
            var biggestIndex = -1
            var biggest = 0.0
            
            for (i, wm) in weightedMessages.enumerated() {
                let wv = wm.get()
                
                if (biggestIndex == -1) || (wv.value >= biggest) {
                    biggestIndex = i
                    biggest = wv.value
                }
            }
            
            _zero(weightedMessages, weight: .std)
            weightedMessages[biggestIndex].set((value: 1.0, weight: .std))
        }
    } else {
        let infZeroMagic = edges.count - 1
        
        f = {
            weightedMessages in
            
            var infOneIndex = -1
            var nonInfZeroIndex = -1
            var countInfZero = 0
            var biggestStdIndex = -1
            var biggestStd = 0.0
            var biggestZeroIndex = -1
            var biggestZero = 0.0
            
            for (i, wm) in weightedMessages.enumerated() {
                let wv = wm.get()
                
                if wv.weight == .inf {
                    if wv.value.isZero {
                        countInfZero += 1
                    } else {
                        // assume value is 1
                        infOneIndex = i
                        break
                    }
                } else {
                    nonInfZeroIndex = i
                    
                    if wv.weight == .zero {
                        if (biggestZeroIndex == -1) || (wv.value >= biggestZero) {
                            biggestZeroIndex = i
                            biggestZero = wv.value
                        }
                    } else {
                        if (biggestStdIndex == -1) || (wv.value >= biggestStd) {
                            biggestStdIndex = i
                            biggestStd = wv.value
                        }
                    }
                }
            }
            
            let oneIndex: Int
            var newWeight: MessageWeight = .std
            
            if infOneIndex != -1 {
                newWeight = .inf
                oneIndex = infOneIndex
            } else if (countInfZero == infZeroMagic) {
                newWeight = .inf
                oneIndex = nonInfZeroIndex
            } else if (biggestStdIndex != -1) {
                oneIndex = biggestStdIndex
            } else {
                oneIndex = biggestZeroIndex
            }
            
            _zero(weightedMessages, weight: newWeight)
            weightedMessages[oneIndex].set((value: 1.0, weight: newWeight))
        }
    }
    
    return obj.createFactor(edges: edges, f)
}
