//
//  main.swift
//  ThePerfectAligner
//
//  Created by Kenneth Durbrow on 12/14/15.
//  Copyright © 2015 Kenneth Durbrow. All rights reserved.
//

import Foundation

protocol Read {
    var position: Int { get }
    var length: Int { get }
    var reversed: Bool { get }
}

protocol Spot {
    var name: String { get }
    var templateLength: Int { get }
    var reads: Int { get }
    subscript(readNo: Int) -> Read { get }
}

func normalRandom() -> (Double, Double)
{
    repeat {
        let x1 = 0x1.0p-30 * Double(random()) - 1.0
        let x2 = 0x1.0p-30 * Double(random()) - 1.0
        let w = x1 * x1 + x2 * x2
        if 0.0 < w && w <= 1.0 {
            let s = sqrt((-2.0 * log(w))/w)
            return (x1 * s, x2 * s)
        }
    }
}

struct Illumina {
    struct _Read {
        let position: Int
        let length: Int
        let reversed: Bool
    }
    struct _Spot {
        let name: String
        let read: [_Read]
    }
}

extension Illumina._Read : Read {}

extension Illumina._Spot : Spot {
    var templateLength : Int {
        get { return read[1].position + read[1].length }
    }
    var reads: Int { get { return 2 } }
    subscript(readNo: Int) -> Read { get { return read[readNo] } }
}

extension Illumina {
    static func randomSpots(readLength readLength: Int, templateLengthAvg: Int, templatelengthStDev: Int) -> AnyGenerator<Spot> {
        assert(2 * readLength < templateLengthAvg)
        var serialNo = 0
        return AnyGenerator {
            repeat {
                let r = normalRandom()
                let ipd = templateLengthAvg - 2 * readLength
                let dif = Int(Double(templatelengthStDev) * r.0)
                let s2 = readLength + ipd + dif
                let rev = r.1 < 0
                if s2 > readLength {
                    serialNo += 1
                    return _Spot(name: "\(serialNo)", read: [_Read(position: 0, length: readLength, reversed: rev), _Read(position: s2, length: readLength, reversed: !rev)])
                }
            }
        }
    }
}

struct Alignment {
    let name: String
    let readNo: Int
    let range: Range<Int>
    let reversed: Bool
}

extension Alignment : Equatable {}
func ==(lhs: Alignment, rhs: Alignment) -> Bool {
    return lhs.name == rhs.name && lhs.readNo == rhs.readNo
}

extension Alignment : Comparable {}
func <(lhs: Alignment, rhs: Alignment) -> Bool {
    return lhs.range.startIndex == rhs.range.startIndex ? lhs.range.endIndex < rhs.range.endIndex : lhs.range.startIndex < rhs.range.startIndex
}

extension Alignment : Hashable {
    var hashValue : Int {
        get {
            let s = "\(name)\t\(readNo)\n"
            return s.hashValue
        }
    }
}

func templateLength(a: Alignment, b: Alignment) -> Int
{
    let aleft = a.reversed ? a.range.endIndex.predecessor() : a.range.startIndex
    let aright = a.reversed ? a.range.startIndex.predecessor() : a.range.endIndex
    let bleft = b.reversed ? b.range.endIndex.predecessor() : b.range.startIndex
    let bright = b.reversed ? b.range.startIndex.predecessor() : b.range.endIndex
    let left = min(aleft, bleft)
    let right = max(aright, bright)
    let value = right - left
    if aright == right {
        return -value
    }
    else {
        return value
    }
}

func tile(referenceLength: Int, depthOfCoverage: Int, source: AnyGenerator<Spot>) -> [Alignment]
{
    var coverage = 0
    var result = [Alignment]()
    var pos = 0
    
    for s in GeneratorSequence(source) {
        var p = 100

        for i in 0..<s.reads {
            let r = s[i]
            p = max(p, r.position + r.length)
            let a = Alignment(name: s.name, readNo: i + 1, range: pos+r.position..<pos+r.position+r.length, reversed: r.reversed)
            result.append(a)
            coverage += r.length
        }

        let averageCoverage = Double(coverage) / Double(referenceLength)
        if averageCoverage > Double(depthOfCoverage) { break }
        
        let inc = random() % p
        pos = (pos + inc) % referenceLength
    }
    return result
}

func baseString(ref: ArraySlice<UInt8>) -> String
{
    var rslt = ""
    rslt.reserveCapacity(ref.count)
    for b in ref {
        switch b {
        case 1:
            rslt.append(Character("A"))
        case 2:
            rslt.append(Character("C"))
        case 3:
            rslt.append(Character("G"))
        case 4:
            rslt.append(Character("T"))
        default:
            rslt.append(Character("N"))
        }
    }
    return rslt
}

srandomdev()
let p = Set<Alignment>(tile(500_000, depthOfCoverage: 30, source: Illumina.randomSpots(readLength: 150, templateLengthAvg: 1000, templatelengthStDev: 200)))
let m = p.reduce(0) { max($0, $1.range.endIndex) }
let s = Set<Alignment>(tile(m, depthOfCoverage: 30, source: Illumina.randomSpots(readLength: 150, templateLengthAvg: 1000, templatelengthStDev: 200))).intersect(p)
var r = [UInt8](count: s.reduce(m, combine: { max($0, $1.range.endIndex) }), repeatedValue: 0)
for sa in s {
    let pa = p[p.indexOf(sa)!]
    let pr = pa.range
    let sr = sa.range
    if (pr.startIndex <= sr.startIndex && sr.startIndex < pr.endIndex) || (pr.startIndex < sr.endIndex && sr.endIndex <= pr.endIndex) { continue }

    for (i, pi) in pr.enumerate() {
        guard r[pi] == 0 else { continue }
        let si = sr.startIndex.advancedBy(i)
        let b = si < sr.endIndex ? r[si] : 0
        r[pi] = b != 0 ? b : UInt8(random() % 4) + 1
    }
    for (i, si) in sr.enumerate() {
        guard r[si] == 0 else { continue }
        let pi = pr.startIndex.advancedBy(i)
        let b = pi < pr.endIndex ? r[pi] : (UInt8(random() % 4) + 1)
        r[si] = b
    }
}

class WriteFile {
    let fp: UnsafeMutablePointer<FILE>
    
    init(path: String) {
        fp = fopen(path, "w")
    }
    deinit {
        fclose(fp)
    }
}

extension WriteFile : OutputStreamType {
    func write(string: String) {
        let a = Array(string.utf8)
        a.withUnsafeBufferPointer { fwrite($0.baseAddress, 1, $0.count, self.fp) }
    }
}

func writeReference()
{
    var f = WriteFile(path: "R.fasta")
    print(">R A. randomus chromosome R", separator: "", terminator: "\n", toStream: &f)
    var i = r.startIndex
    while i < r.endIndex {
        let w = i.advancedBy(70)
        let e = min(w, r.endIndex)
        print(baseString(r[i..<e]), separator: "", terminator: "\n", toStream: &f)
        i = e
    }
}

writeReference()
print("@HD\tVN:1.0\tSO:unknown")
print("@SQ\tSN:R\tLN:\(r.count)")
for pa in p {
    let mate = p[p.indexOf(Alignment(name: pa.name, readNo: pa.readNo == 1 ? 2 : 1, range: 0...0, reversed: false))!]
    let QNAME = pa.name
    let FLAG = 0x1 | 0x2 | (pa.reversed ? 0x10 : 0) | (mate.reversed ? 0x20 : 0) | (pa.readNo == 1 ? 0x40 : 0) | (pa.readNo == 2 ? 0x80 : 0)
    let POS = pa.range.startIndex.successor()
    let CIGAR = "\(pa.range.startIndex.distanceTo(pa.range.endIndex))M"
    let RNEXT = "="
    let PNEXT = mate.range.startIndex.successor()
    let TLEN = templateLength(pa, b: mate)
    let seq = r[pa.range]
    let SEQ = baseString(seq)
    let QUAL = String(pa.range.map({ _ -> Character in
        repeat {
            let v = Int(normalRandom().1 * 10.0 + 30)
            if 20...40 ~= v {
                return Character(UnicodeScalar(v + 33))
            }
        }
    }))
    print(QNAME, FLAG, "R", POS, 30, CIGAR, "=", PNEXT, TLEN, SEQ, QUAL, separator: "\t", terminator: "\n")
    
    if let si = s.indexOf(pa) {
        let sa = s[si]
        let NM = zip(seq, r[sa.range]).filter({ $0.0 == $0.1 }).count
        if NM * 2 > sa.range.startIndex.distanceTo(sa.range.endIndex) { continue }
        let mate = s[s.indexOf(Alignment(name: sa.name, readNo: sa.readNo == 1 ? 2 : 1, range: 0...0, reversed: false))!]
        let FLAG = 0x1 | 0x2 | 0x100 | (sa.reversed ? 0x10 : 0) | (mate.reversed ? 0x20 : 0) | (sa.readNo == 1 ? 0x40 : 0) | (sa.readNo == 2 ? 0x80 : 0)
        let POS = sa.range.startIndex.successor()
        let CIGAR = "\(sa.range.startIndex.distanceTo(sa.range.endIndex))M"
        let PNEXT = mate.range.startIndex.successor()
        let TLEN = templateLength(sa, b: mate)
        print(QNAME, FLAG, "R", POS, 3, CIGAR, "=", PNEXT, TLEN, SEQ, QUAL, "NM:i:\(NM)", separator: "\t", terminator: "\n")
    }
}
