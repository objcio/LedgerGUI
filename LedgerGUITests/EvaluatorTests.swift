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

struct Commodity: Equatable, Hashable {
    var value: String?
    
    var hashValue: Int {
        return value?.hashValue ?? 0
    }
    
    init(_ value: String?) {
        self.value = value
    }
}

func ==(x: Commodity, y: Commodity) -> Bool {
    return x.value == y.value
}

struct State {
    typealias Balance = [String: [Commodity:LedgerDouble]]
    var year: Int? = nil
    var definitions: [String: Value] = [:]
    var accounts: Set<String> = []
    var commodities: Set<String> = []
    var tags: Set<String> = []
    var balance: Balance = [:]
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

extension Dictionary {
    subscript(key: Key, or defaultValue: Value) -> Value {
        get {
            return self[key] ?? defaultValue
        }
        set {
            self[key] = newValue
        }
    }
}

extension Array {
    mutating func remove(where test: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        var newSelf: [Element] = []
        for x in self {
            if test(x) {
                result.append(x)
            } else {
                newSelf.append(x)
            }
        }
        self = newSelf
        return result
    }
}

extension Posting {
    func match(expression: Expression) throws -> Bool {
        let value = try expression.evaluate { name in
            if name == "account" {
                return .string(self.account)
            }
            return nil
        }
        guard case .bool(let result) = value else {
            throw "Expected boolean expression"
        }
        return result
    }
}

enum Value: Equatable {
    case amount(Amount)
    case string(String)
    case regex(String)
    case bool(Bool)
}

func ==(lhs: Value, rhs: Value) -> Bool {
    switch (lhs,rhs) {
    case let (.amount(x), .amount(y)): return x == y
    case let (.string(x), .string(y)): return x == y
    case let (.regex(x), .regex(y)): return x == y
    case let (.bool(x), .bool(y)): return x == y
    default: return false
    }
}

extension Value {
    func op(_ f: (LedgerDouble, LedgerDouble) -> LedgerDouble, _ other: Value) throws -> Amount {
        guard case .amount(let selfAmount) = self, case .amount(let otherAmount) = other else {
            throw "Arithmetic operator on non-amount" // todo better failure message
        }
        return try selfAmount.op(f, otherAmount)
    }
    
    func matches(_ rhs: Value) throws -> Bool {
        guard case let .string(string) = self, case let .regex(regex) = rhs else {
            throw "Regular expression match on non string/regex"
        }
        let range = NSRange(location: 0, length: (string as NSString).length)
        return try RegularExpression(pattern: regex, options: []).firstMatch(in: string, options: [], range: range) != nil
    }
}

extension Expression {
    func evaluate(lookup: (String) -> Value? = { _ in return nil }) throws -> Value {
        switch self {
        case .amount(let amount):
            return .amount(amount)
        case .infix(let op, let lhs, let rhs):
            let left = try lhs.evaluate(lookup: lookup)
            let right = try rhs.evaluate(lookup: lookup)
            switch op {
            case "*":
                return try .amount(left.op(*, right))
            case "/":
                return try .amount(left.op(/, right))
            case "+":
                return try .amount(left.op(+, right))
            case "-":
                return try .amount(left.op(-, right))
            case "=~":
                return try .bool(left.matches(right))
            default:
                fatalError()
            }
            
        case .ident(let name):
            guard let value = lookup(name) else { throw "Variable \(name) not defined"}
            return value
        case .string(let string):
            return .string(string)
        case .regex(let regex):
            return .regex(regex)
        default:
            fatalError()
        }

    }
}

extension State {
    mutating func apply(_ statement: Statement) throws {
        switch statement {
        case .year(let year):
            self.year = year
        case .definition(let name, let expression):
            definitions[name] = try expression.evaluate(lookup: get)
        case .account(let name):
            accounts.insert(name)
        case .commodity(let name):
            commodities.insert(name)
        case .tag(let name):
            tags.insert(name)
        case .comment:
            break
        case .transaction(let transaction):
            balance = try computeNewBalance(postings: transaction.postings)
        default:
            fatalError()
        }
    }
    
    // This method is not mutating. This prevents us from accidentally mutating `balance` (we might throw during a transaction)
    func computeNewBalance(postings: [Posting]) throws -> Balance {
        var newBalance = balance
        var total: [Commodity: LedgerDouble] = [:]
        var postingsWithValue = postings
        let postingsWithoutValue = postingsWithValue.remove { $0.value == nil }
        guard postingsWithoutValue.count <= 1 else { throw "More than one posting without value" }
        
        for posting in postingsWithValue {
            var accountBalance = newBalance[posting.account] ?? [:]
            let value = try posting.value!.evaluate(lookup: get)
            guard case .amount(let amount) = value else {
                throw "Posting value evaluates to a non-amount"
            }
            let commodity = Commodity(amount.commodity)
            total[commodity, or: 0] += amount.number
            accountBalance[commodity, or: 0] += amount.number
            newBalance[posting.account] = accountBalance
        }
        
        for (commodity, value) in total {
            if let postingWithoutValue = postingsWithoutValue.first {
                newBalance[postingWithoutValue.account, or: [:]][commodity, or: 0] -= value
            } else {
                guard value == 0 else { throw "Postings of commodity \(commodity) not balanced: \(value)" }
            }
        }
        return newBalance
    }
    
    
    func get(definition name: String) -> Value? {
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
    
    func balance(account: String) -> [Commodity:LedgerDouble] {
        return self.balance[account] ?? [:]
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
        XCTAssert(state.get(definition: name) == .amount(amount))

        let amount2 = Amount(number: 3, commodity: "EUR")
        let directive2 = Statement.definition(name: name, expression: .amount(amount2))
        try! state.apply(directive2)
        XCTAssert(state.get(definition: name) == .amount(amount2))
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
        let expression = Expression.infix(operator: "*", lhs: .amount(Amount(number: 2, commodity: "EUR")), rhs: .amount(Amount(number: 3)))
        let result = try! expression.evaluate()
        XCTAssert(result == .amount(Amount(number: 6, commodity: "EUR")))
        
        let amount = Value.amount(Amount(number: 3))
        let lookup: (String) -> Value? = { if $0 == "foo" { return amount } else { return nil } }
        XCTAssert(try! Expression.ident("foo").evaluate(lookup: lookup) == amount)
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
    
    func testTransaction() {
        var state = State()
        let date = LedgerGUI.Date(year: 2015, month: 1, day: 16)
        let posting1 = Posting(account: "Giro", amount: Amount(number: 100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let posting2 = Posting(account: "Cash", amount: Amount(number: -100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let transaction = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2]))
        try! state.apply(transaction)
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 100])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -100])
        try! state.apply(transaction)
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 200])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -200])
    }
    
    func testAutoBalancing() {
        var state = State()
        let date = LedgerGUI.Date(year: 2015, month: 1, day: 16)
        let posting1 = Posting(account: "Giro", amount: Amount(number: 100, commodity: "USD"))
        let posting2 = Posting(account: "Cash", value: nil)
        let posting3 = Posting(account: "Giro", amount: Amount(number: 200, commodity: "EUR"))
        
        try! state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2])))
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 100])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -100])
        
        state = State()
        try! state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting1, posting2])))
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 200])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -200])
        
        state = State()
        try! state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2, posting3])))
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 100, Commodity("EUR"): 200])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -100, Commodity("EUR"): -200])
        
        XCTAssertNil(try? state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2, posting2]))))
    }
    
    func testBalanceVerification() {
        var state = State()
        let date = LedgerGUI.Date(year: 2015, month: 1, day: 16)
        let posting1 = Posting(account: "Giro", amount: Amount(number: 100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let posting2 = Posting(account: "Cash", amount: Amount(number: -200, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let transaction = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2]))
        XCTAssertNil(try? state.apply(transaction))

        let posting3 = Posting(account: "Giro", amount: Amount(number: 100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let posting4 = Posting(account: "Cash", amount: Amount(number: -100, commodity: "EUR"), cost: nil, balance: nil, note: nil)
        let transaction2 = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting3, posting4]))
        XCTAssertNil(try? state.apply(transaction2))
        
        let transaction3 = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting1, posting2]))
        XCTAssertNotNil(try? state.apply(transaction3))
    }
    
    func testRegex() {
        let expression = Expression.infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Gir"))
        let posting = Posting(account: "Assets:Giro")
        XCTAssertTrue(try! posting.match(expression: expression))
    }
}
