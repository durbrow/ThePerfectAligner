//
//  DNABase.swift
//  ThePerfectAligner
//
//  Created by Kenneth Durbrow on 12/14/15.
//  Copyright © 2015 Kenneth Durbrow. All rights reserved.
//

import Foundation

private func random4() -> UInt8
{
    return UInt8(Darwin.random() % 4)
}

enum DNABase : UInt8 {
    case N = 0
    case A
    case C
    case G
    case T

    init(Character ch: Character)
    {
        switch ch {
        case "A", "a":
            self = .A
        case "C", "c":
            self = .C
        case "G", "g":
            self = .G
        case "T", "t":
            self = .T
        default:
            self = .N
        }
    }
}

extension DNABase {
    static func random() -> DNABase
    {
        return DNABase(rawValue: random4() + 1)!
    }
}

extension DNABase : CustomStringConvertible {
    var description : String {
        get {
            let tr = ["N", "A", "C", "G", "T"]
            return tr[Int(rawValue)]
        }
    }
}

struct DNASequence {
    let data : [DNABase]
    let defline : String
    
    private init(rawData src: NSData, defline: String)
    {
        let wsset = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        var data = [DNABase]()
        
        src.enumerateByteRangesUsingBlock { (b, r, S) -> Void in
            let cdata = UnsafePointer<Int8>(b)
            
            for i in 0..<r.length {
                let chi = cdata[i];
                if wsset.characterIsMember(UInt16(chi)) {
                    continue
                }
                data.append(DNABase(Character: Character(UnicodeScalar(Int(chi)))))
            }
        }
        self.data = data
        self.defline = defline
    }
    init(data: [DNABase], defline: String)
    {
        self.data = data
        self.defline = defline
    }
    init<S: SequenceType where S.Generator.Element == DNABase>(s: S, defline: String)
    {
        self.data = [DNABase](s)
        self.defline = defline
    }
    init<S: SequenceType where S.Generator.Element == Character>(s: S, defline: String)
    {
        self.data = s.map { DNABase(Character: $0) }
        self.defline = defline
    }
}

extension DNASequence {
    static func randomSequence(length: Int) -> [DNABase]
    {
        assert(length > 0)
        var rslt = (0..<length).map { DNABase(rawValue: UInt8($0 % 4) + 1)! }

        srandomdev()
        for i in 0..<length {
            let j = random() % length
            (rslt[j], rslt[i]) = (rslt[i], rslt[j])
        }
        return rslt
    }
    static func repeatedSequence(count: Int, subSequence: String) -> [DNABase]
    {
        guard count > 0 && subSequence != "" else { return [] }

        let seq = subSequence.characters.map { DNABase(Character: $0) }
        guard seq.count > 1 else { return [DNABase](count: count, repeatedValue: seq[0]) }

        var rslt = [DNABase]()
        rslt.reserveCapacity(count * seq.count)
        for _ in 0 ..< count {
            rslt.appendContentsOf(seq)
        }
        return rslt
    }
}

extension DNASequence {
    static func load<S: SequenceType where S.Generator.Element == UInt8>(Fasta src: S) -> [DNASequence]
    {
        var result : [DNASequence] = []
        var lineno = 1
        var st = 0
        var ws = true
        var defline = ""
        var accum = [DNABase]()
        
        for u in src {
            let ch = ASCII(rawValue: u)!
            if ch == .LF { lineno += 1 }
            if ws && ch.isSpace { continue }
            ws = false
            switch st {
            case 0:
                if ch != ">" {
                    st = -1
                }
                else {
                    st = 1
                }
            case 1:
                if ch == .LF {
                    st = 2
                }
                else {
                    defline.append(ch.characterValue)
                }
            case 2:
                if ch == .LF {
                    st = 3
                }
                else {
                    accum.append(DNABase(rawValue: DNABase.RawValue(ch.rawValue))!)
                }
            case 3:
                if ch == ">" {
                    result.append(DNASequence(data: accum, defline: defline))
                }
            default:
                break
            }
            if st < 0 { return [] }
        }
        return result
    }
    static func load(contentsOfFile path: String) throws -> [DNASequence]
    {
        enum State {
            case start
            case deflineStart
            case defline
            case sequenceStart
            case sequence
            case sequenceEnd
            case invalid
        }
        var result : [DNASequence] = []
        let src = try NSData(contentsOfFile: path, options: [.DataReadingMappedIfSafe])
        var part = [Int]()
        var invalid = -1
        var ws = true
        let wsset = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        var st = State.start
        var lineno = 1
        
        src.enumerateByteRangesUsingBlock { (data, range, STOP) -> Void in
            let cdata = UnsafePointer<Int8>(data)
            
            for i in 0..<range.length {
                let chi = cdata[i]
                let ch = Character(UnicodeScalar(Int(chi)))
                
                if ch == "\n" { lineno += 1 }
                if wsset.characterIsMember(UInt16(chi)) && ws {
                    continue
                }
                ws = false
                switch st {
                case .start:
                    if ch != ">" {
                        st = .invalid
                    }
                    else {
                        ws = true
                        st = .deflineStart
                    }
                case .deflineStart:
                    part.append(range.location + i)
                    st = .defline
                case .defline:
                    if ch == "\n" {
                        st = .sequenceStart
                        ws = true
                    }
                case .sequenceStart:
                    part.append(range.location + i)
                    st = .sequence
                case .sequence:
                    switch ch {
                    case "\n":
                        ws = true
                        st = .sequenceEnd
                    case "A", "C", "G", "T", "a", "c", "g", "t", "N":
                        break
                    default:
                        st = .invalid
                    }
                case .sequenceEnd:
                    if ch == ">" {
                        ws = true
                        st = .deflineStart
                    }
                    else {
                        st = .sequence
                    }
                case .invalid:
                    assertionFailure()
                }
                if st == .invalid {
                    invalid = lineno + 1
                    STOP[0] = true
                    break
                }
            }
        }
        if invalid >= 0 {
            assertionFailure("Invalid FASTA at line \(invalid)")
        }
        if part.count > 0 && part.count % 2 == 0 {
            let N = part.count / 2

            part.append(src.length)
            for i in 0..<N {
                let p = part[2 * i ... 2 * i + 2]
                let defline = NSString(data: src.subdataWithRange(NSMakeRange(p[0] + 1, p[1] - p[0] - 2)),
                    encoding: NSASCIIStringEncoding)!
                result.append(DNASequence(rawData: src.subdataWithRange(NSMakeRange(p[1], p[2] - p[1])),
                    defline: defline as String))
            }
        }
        return result
    }
}

extension DNASequence : CollectionType {
    typealias Element = DNABase
    var startIndex: Int {
        get { return 0 }
    }
    var endIndex: Int {
        get { return data.count }
    }
    subscript (index: Int) -> DNABase {
        return data[index]
    }
}
