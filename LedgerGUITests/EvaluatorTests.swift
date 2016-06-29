//
//  EvaluatorTests.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 29/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

import XCTest
@testable import LedgerGUI

struct State {
    var year: Int? = nil
    var definitions: [String: Amount] = [:]
    var accounts: Set<String> = []
    var commodities: Set<String> = []
    var tags: Set<String> = []
}

extension String: ErrorProtocol {}

func merge(commodity1: String?, commodity2: String?) throws -> String? {
    switch (commodity1, commodity2) {
    case (nil, nil):
        return nil
    case (nil, let c):
        return c
    case (let c, nil):
        return c
    case (let c1, let c2) where c1 == c2:
        return c1
    default:
        throw "Commodities (\(commodity1), \(commodity2)) can't be merged"
    }
}

extension Amount {
    func op(_ f: (LedgerDouble, LedgerDouble) -> LedgerDouble, _ other: Amount) throws -> Amount {
        let commodity = try merge(commodity1: self.commodity, commodity2: other.commodity)
        return Amount(number: f(self.number, other.number), commodity: commodity)
    }
}


extension State {
    mutating func apply(_ statement: Statement) throws {
        switch statement {
        case .year(let year):
            self.year = year
        case .definition(let name, let expression):
            definitions[name] = try evaluate(expression: expression)
        case .account(let name):
            accounts.insert(name)
        case .commodity(let name):
            commodities.insert(name)
        case .tag(let name):
            tags.insert(name)
        case .comment:
            break
        default:
            fatalError()
        }
    }

    func evaluate(expression: Expression) throws -> Amount {
        switch expression {
        case .amount(let amount):
            return amount
        case .infix(let op, let lhs, let rhs):
            let left = try evaluate(expression: lhs)
            let right = try evaluate(expression: rhs)
            let operatorFunction: (LedgerDouble, LedgerDouble) -> LedgerDouble
            switch op {
            case "*": operatorFunction = (*)
            case "/": operatorFunction = (/)
            case "+": operatorFunction = (+)
            case "-": operatorFunction = (-)
            default:
                fatalError()
            }
            return try left.op(operatorFunction, right)
        case .ident(let name):
            guard let value = get(definition: name) else { throw "Variable \(name) not defined"}
            return value
        default:
            fatalError()
        }
    }

    func get(definition name: String) -> Amount? {
        return definitions[name]
    }

    func valid(account: String) -> Bool {
        return accounts.contains(account)
    }

    func valid(commodity: String) -> Bool {
        return commodities.contains(commodity)
    }

    func valid(tag: String) -> Bool {
        return tags.contains(tag)
    }
}

class EvaluatorTests: XCTestCase {
    func testYear() {
        let directive = Statement.year(2005)
        var state = State()
        try! state.apply(directive)
        XCTAssert(state.year == 2005)
    }

    func testDefine() {
        let name = "exchange_rate"
        var state = State()

        let amount = Amount(number: 2, commodity: "EUR")
        let directive = Statement.definition(name: name, expression: .amount(amount))
        try! state.apply(directive)
        XCTAssert(state.get(definition: name) == amount)

        let amount2 = Amount(number: 3, commodity: "EUR")
        let directive2 = Statement.definition(name: name, expression: .amount(amount2))
        try! state.apply(directive2)
        XCTAssert(state.get(definition: name) == amount2)
    }

    func testAccount() {
        let name = "Some:Account"
        let account = Statement.account(name)
        var state = State()
        XCTAssertFalse(state.valid(account: name))
        try! state.apply(account)
        XCTAssertTrue(state.valid(account: name))
    }

    func testCommodity() {
        let name = "EUR"
        let commodity = Statement.commodity(name)
        var state = State()
        XCTAssertFalse(state.valid(commodity: name))
        try! state.apply(commodity)
        XCTAssertTrue(state.valid(commodity: name))
    }

    func testTag() {
        let name = "tag"
        let tag = Statement.tag(name)
        var state = State()
        XCTAssertFalse(state.valid(tag: name))
        try! state.apply(tag)
        XCTAssertTrue(state.valid(tag: name))
    }

    func testEvaluateExpression() {
        var state = State()
        let expression = Expression.infix(operator: "*", lhs: .amount(Amount(number: 2, commodity: "EUR")), rhs: .amount(Amount(number: 3)))
        let result = try! state.evaluate(expression: expression)
        XCTAssert(result == Amount(number: 6, commodity: "EUR"))

        let amount = Amount(number: 3)
        let define = Statement.definition(name: "foo", expression: .amount(amount))
        try! state.apply(define)
        let expr = Expression.ident("foo")
        XCTAssert(try! state.evaluate(expression: expr) == amount)
    }

    func testAmountMultiplication() {
        let a1 = Amount(number: 3)
        let a2 = Amount(number: 5)
        let a3 = Amount(number: 7, commodity: "EUR")
        let a4 = Amount(number: 11, commodity: "$")
        XCTAssertTrue(try! a1.op(*, a2) == Amount(number: 15))
        XCTAssertTrue(try! a1.op(*, a3) == Amount(number: 21, commodity: "EUR"))
        XCTAssertTrue(try! a4.op(*, a2) == Amount(number: 55, commodity: "$"))
        XCTAssertNil(try? a3.op(*, a4))
    }
}
