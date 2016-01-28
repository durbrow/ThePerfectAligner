//
//  ASCII.swift
//
//  Created by Kenneth Durbrow on 1/22/16.
//  Copyright © 2016 Kenneth Durbrow. All rights reserved.
//

import Darwin.POSIX.ctype

enum ASCII : UInt8 {
    case NUL
    case SOH
    case STX
    case ETX
    case EOT
    case ENQ
    case ACK
    case BEL
    case BS
    case HT
    case LF
    case VT
    case FF
    case CR
    case SO
    case SI
    case DLE
    case XON
    case DC2
    case XOFF
    case DC4
    case NAK
    case SYN
    case ETB
    case CAN
    case EM
    case SUB
    case ESC
    case FS
    case GS
    case RS
    case US
    
    case SPACE
    case EXCLAMATION
    case DQUOTE
    case HASH
    case DOLLAR
    case PERCENT
    case AMPERSAND
    case SQUOTE
    case OPEN_PAREN
    case CLOSE_PAREN
    case ASTERISK
    case PLUS
    case COMMA
    case MINUS
    case POINT
    case SLASH
    
    case DIGIT_0
    case DIGIT_1
    case DIGIT_2
    case DIGIT_3
    case DIGIT_4
    case DIGIT_5
    case DIGIT_6
    case DIGIT_7
    case DIGIT_8
    case DIGIT_9
    
    case COLON
    case SEMICOLON
    case LT
    case EQ
    case GT
    case QUESTION
    case AT
    
    case UPPER_A
    case UPPER_B
    case UPPER_C
    case UPPER_D
    case UPPER_E
    case UPPER_F
    case UPPER_G
    case UPPER_H
    case UPPER_I
    case UPPER_J
    case UPPER_K
    case UPPER_L
    case UPPER_M
    case UPPER_N
    case UPPER_O
    case UPPER_P
    case UPPER_Q
    case UPPER_R
    case UPPER_S
    case UPPER_T
    case UPPER_U
    case UPPER_V
    case UPPER_W
    case UPPER_X
    case UPPER_Y
    case UPPER_Z
    
    case OPEN_BRACKET
    case BACKSLASH
    case CLOSE_BRACKET
    case CARET
    case UNDERSCORE
    case GRAVE_ACCENT
    
    case LOWER_A
    case LOWER_B
    case LOWER_C
    case LOWER_D
    case LOWER_E
    case LOWER_F
    case LOWER_G
    case LOWER_H
    case LOWER_I
    case LOWER_J
    case LOWER_K
    case LOWER_L
    case LOWER_M
    case LOWER_N
    case LOWER_O
    case LOWER_P
    case LOWER_Q
    case LOWER_R
    case LOWER_S
    case LOWER_T
    case LOWER_U
    case LOWER_V
    case LOWER_W
    case LOWER_X
    case LOWER_Y
    case LOWER_Z
    
    case OPEN_BRACE
    case V_BAR
    case CLOSE_BRACE
    case TILDE
    
    case DEL = 0x7F
    
    var isCntrl : Bool { get { return self < SPACE || self == DEL } }
    var isPrint : Bool { get { return !isCntrl } }

    var isDigit : Bool { get { return DIGIT_0...DIGIT_9 ~= self } }
    var isLower : Bool { get { return LOWER_A...LOWER_Z ~= self } }
    var isUpper : Bool { get { return UPPER_A...UPPER_Z ~= self } }

    var isBlank : Bool { get { return self == HT || self == SPACE } }
    
    var isSpace : Bool { get { return isBlank || LF...CR ~= self } }
    var isXDigit: Bool { get { return isDigit || UPPER_A...UPPER_F ~= self || LOWER_A...LOWER_F ~= self } }
    
    var isAlpha : Bool { get { return isUpper || isLower } }
    var isAlNum : Bool { get { return isDigit || isAlpha } }
    var isGraph : Bool { get { return isPrint && self != SPACE } }
    var isPunct : Bool { get { return isGraph && !isAlNum } }
    
    var toLower : ASCII { get { return isUpper ? LOWER_A.advancedBy(UPPER_A.distanceTo(self)) : self } }
    var toUpper : ASCII { get { return isLower ? UPPER_A.advancedBy(LOWER_A.distanceTo(self)) : self } }

    /// casts to a Swift character
    var characterValue : Character { get { return Character(UnicodeScalar(self.rawValue)) } }
    
    /// casts to a UInt16
    var uInt16Value : UInt16 { get { return UInt16(self.rawValue) } }
    
    /// converts a hexadecimal digit character to its corresponding integer value
    /// return -1 if isXDigit would return false
    var numberValue : Int {
        get {
            return DIGIT_0...DIGIT_9 ~= self ? (     DIGIT_0.distanceTo(self))
                 : LOWER_A...LOWER_F ~= self ? (10 + LOWER_A.distanceTo(self))
                 : UPPER_A...UPPER_F ~= self ? (10 + UPPER_A.distanceTo(self))
                 : -1
        }
    }
}

extension ASCII : Comparable {}
func <(lhs: ASCII, rhs: ASCII) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

extension ASCII : ForwardIndexType {
    func successor() -> ASCII {
        return ASCII(rawValue: self.rawValue + 1)!
    }
    
    func distanceTo(other: ASCII) -> Int
    {
        return Int(other.rawValue) - Int(self.rawValue)
    }
    
    func advancedBy(n: Int) -> ASCII
    {
        return ASCII(rawValue: RawValue(Int(self.rawValue) + n))!
    }
}

extension ASCII : BidirectionalIndexType {
    func predecessor() -> ASCII {
        return ASCII(rawValue: self.rawValue - 1)!
    }
}

extension ASCII : RandomAccessIndexType {
}

extension ASCII : UnicodeScalarLiteralConvertible {
    init(unicodeScalarLiteral value: StaticString) {
        self.init(stringLiteral: value)
    }
}

extension ASCII : ExtendedGraphemeClusterLiteralConvertible {
    init(extendedGraphemeClusterLiteral value: StaticString) {
        self.init(stringLiteral: value)
    }
}

extension ASCII : StringLiteralConvertible {
    init(stringLiteral value: StaticString) {
        var raw : RawValue = 0
        if value.hasPointerRepresentation {
            if value.byteSize == 1 {
                raw = value.utf8Start[0]
            }
        }
        else if value.unicodeScalar.value < 0x80 {
            raw = RawValue(value.unicodeScalar.value)
        }
        self.init(rawValue: raw)!
    }
}
