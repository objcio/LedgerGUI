//
//  LedgerDouble.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 04/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

struct LedgerDouble: Equatable, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    var value: Double
    init(_ value: Double) {
        self.value = value
    }

    init(floatLiteral value: Double) {
        self.value = value
    }

    init(integerLiteral value: Double) {
        self.value = value
    }

    init?(_ string: String) {
        guard let value = Double(string) else { return nil }
        self.value = value
    }
}

func ==(lhs: LedgerDouble, rhs: LedgerDouble) -> Bool {
    if rhs.value == 0 {
       return abs(lhs.value) < 0.000000001
    }
    return lhs.value == rhs.value
}

func +(lhs: LedgerDouble, rhs: LedgerDouble) -> LedgerDouble {
    return LedgerDouble(lhs.value + rhs.value)
}
func -(lhs: LedgerDouble, rhs: LedgerDouble) -> LedgerDouble {
    return LedgerDouble(lhs.value - rhs.value)
}
func *(lhs: LedgerDouble, rhs: LedgerDouble) -> LedgerDouble {
    return LedgerDouble(lhs.value * rhs.value)
}
func /(lhs: LedgerDouble, rhs: LedgerDouble) -> LedgerDouble {
    return LedgerDouble(lhs.value / rhs.value)
}

prefix func -(lhs: LedgerDouble) -> LedgerDouble {
    return LedgerDouble(-lhs.value)
}

func +=(lhs: inout LedgerDouble, rhs: LedgerDouble) {
    lhs.value += rhs.value
}

func *=(lhs: inout LedgerDouble, rhs: LedgerDouble) {
    lhs.value *= rhs.value
}


extension LedgerDouble {
    var isNegative: Bool {
        return self.value < 0
    }
}
