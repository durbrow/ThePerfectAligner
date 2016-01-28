//
//  LineSequence.swift
//
//  Created by Kenneth Durbrow on 1/25/16.
//

struct LineSequence<S : SequenceType where S.Generator.Element == Character> {
    typealias Element = String
    private var iter: S.Generator
    private var accum: String
    
    init(_ source: S)
    {
        accum = ""
        iter = source.generate()
    }
}

extension LineSequence : GeneratorType {
    mutating func next() -> Element? {
        for ( ; ; ) {
            guard let ch = iter.next() else { return .None }
            if ch == "\n" {
                let result = accum
                accum = ""
                return result
            }
            accum.append(ch)
        }
    }
}
