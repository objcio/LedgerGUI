//
//  FilterParserTests.swift
//  LedgerGUI
//
//  Created by Florian on 08/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import XCTest
@testable import LedgerGUI

class FilterParserTests: XCTestCase {
    
    func testTokenize() {
        XCTAssert(Filter.tokenize("2015") == [.year(2015)])
        XCTAssert(Filter.tokenize("1888") == [.other("1888")])
        print(Filter.tokenize("June 2013 hallo"))
        XCTAssert(Filter.tokenize("June 2013 hallo") == [.month(6), .year(2013), .other("hallo")])
    }

}
