//
//  LedgerGUITests.swift
//  LedgerGUITests
//
//  Created by Florian on 22/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import XCTest
import SwiftParsec
@testable import LedgerGUI

struct Date {
    let year: Int
    let month: Int
    let day: Int
}

func curry<A, B, C, D>(f: (A, B, C) -> D) -> A -> B -> C -> D {
    return { a in { b in { c in f(a, b, c) } } }
}

extension Date: Equatable {}
func ==(lhs: Date, rhs: Date) -> Bool {
    return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
}

class LedgerGUITests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExample() {
        let dates = ["2016/06/21", "2016-06-21"]
        let failingDates = ["2016/06-21"]
        let int = StringParser.digit.many1.map { Int(String($0))! }
        func monthDay(separator: Character) -> GenericParser<String, (), (Int, Int)> {
            let dateSeparator = StringParser.character(separator)
            return { m in { d in (m, d) } } <^> (dateSeparator *> int) <* dateSeparator <*> int
        }
        let date = { y in { m, d in Date(year: y, month: m, day: d) } } <^> int <*> (monthDay("/") <|> monthDay("-"))
        let expected = Date(year: 2016, month: 6, day: 21)
        for d in dates {
            let result = try? date.run(sourceName: "", input: d)
            XCTAssertTrue(result == expected)
        }
        for d in failingDates {
            XCTAssertNil(try? date.run(sourceName: "", input: d))
        }
    }
}

