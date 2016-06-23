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

class LedgerGUITests: XCTestCase {
    
    func testParser<A: Equatable>(parser: GenericParser<String,(),A>, success: [(String, A)], failure: [String]) {
        for (d, expected) in success {
            let result = try? parser.run(sourceName: "", input: d)
            XCTAssertEqual(result, expected)
        }
        for d in failure {
            XCTAssertNil(try? Date.parser.run(sourceName: "", input: d))
        }
    }
    
    func testDates() {
        let dates = [("2016/06/21", Date(year: 2016, month: 6, day: 21)),
                     ("14-1-31", Date(year: 14, month: 1, day: 31))]
        let failingDates = ["2016/06-21"]
        testParser(Date.parser, success: dates , failure: failingDates)
    }
}

