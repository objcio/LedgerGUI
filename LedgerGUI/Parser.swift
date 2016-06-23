//
//  Parser.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 23/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation
import SwiftParsec

public struct Date {
    public let year: Int
    public let month: Int
    public let day: Int
}

public func curry<A, B, C, D>(f: (A, B, C) -> D) -> A -> B -> C -> D {
    return { a in { b in { c in f(a, b, c) } } }
}

public func curry<A, B, C>(f: (A, B) -> C) -> A -> B -> C {
    return { a in { b in f(a, b) } }
}

extension Date: Equatable {}
public func ==(lhs: Date, rhs: Date) -> Bool {
    return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
}

let int = StringParser.digit.many1.map { Int(String($0))! }
func monthDay(separator: Character) -> GenericParser<String, (), (Int, Int)> {
    let dateSeparator = StringParser.character(separator)
    return curry({ ($0, $1) }) <^> (dateSeparator *> int) <* dateSeparator <*> int
}

extension Date {
    public static let parser:  GenericParser<String, (), Date> =
       { y in { m, d in Date(year: y, month: m, day: d) } } <^> int <*> (monthDay("/") <|> monthDay("-"))
}
