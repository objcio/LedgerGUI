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
    typealias Balance = [String: [Commodity:LedgerDouble]]
    var year: Int? = nil
    var definitions: [String: Value] = [:]
    var accounts: Set<String> = []
    var commodities: Set<String> = []
    var tags: Set<String> = []
    var balance: Balance = [:]
    var automatedTransactions: [AutomatedTransaction] = []
}

extension String: ErrorProtocol {}

extension Commodity {
    func unify(_ other: Commodity) throws -> Commodity {
        switch (value, other.value) {
        case (nil, nil):
            return Commodity()
        case (nil, _):
            return other
        case (_, nil):
            return self
        case (let c1, let c2) where c1 == c2:
            return self
        default:
            throw "Commodities (\(self), \(other)) cannot be unified"
        }
    }
}


extension Amount {
    func op(_ f: (LedgerDouble, LedgerDouble) -> LedgerDouble, _ other: Amount) throws -> Amount {
        let commodity = try self.commodity.unify(other.commodity)
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

extension Transaction {
    func expressionContext(name: String) -> Value? {

        switch name {
        case "year": return self.date.year.map { .amount(Amount(number: LedgerDouble($0))) }
        case "month": return .amount(Amount(number: LedgerDouble(date.month)))
        case "day": return .amount(Amount(number: LedgerDouble(date.day)))
        default:
            return nil
        }
    }
}

extension EvaluatedPosting {
    func expressionContext(name: String) -> Value? {
        switch name {
        case "account": return .string(self.account)
        default:
            return nil
        }
    }
    func match(expression: Expression) throws -> Bool {
        let value = try expression.evaluate(lookup: expressionContext)
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
    func op(double f: (LedgerDouble, LedgerDouble) -> LedgerDouble, _ other: Value) throws -> Amount {
        guard case .amount(let selfAmount) = self, case .amount(let otherAmount) = other else {
            throw "Arithmetic operator on non-amount" // todo better failure message
        }
        return try selfAmount.op(f, otherAmount)
    }
    
    func op(bool f: (Bool, Bool) -> Bool, _ other: Value) throws -> Bool {
        guard case .bool(let selfValue) = self, case .bool(let otherValue) = other else {
            throw "Boolean operator on non-bool" // todo better failure message
        }
        return f(selfValue, otherValue)
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
                return try .amount(left.op(double: *, right))
            case "/":
                return try .amount(left.op(double: /, right))
            case "+":
                return try .amount(left.op(double: +, right))
            case "-":
                return try .amount(left.op(double: -, right))
            case "=~":
                return try .bool(left.matches(right))
            case "&&":
                return try .bool(left.op(bool: { $0 && $1 }, right))
            case "||":
                return try .bool(left.op(bool: { $0 || $1 }, right))
            default:
                fatalError("Unknown operator: \(op)")
            }
            
        case .ident(let name):
            guard let value = lookup(name) else { throw "Variable \(name) not defined"}
            return value
        case .string(let string):
            return .string(string)
        case .regex(let regex):
            return .regex(regex)
        case .bool(let bool):
            return .bool(bool)
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
        case .automated(let autoTransaction):
            automatedTransactions.append(autoTransaction)
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
        
        var evaluatedPostings: [EvaluatedPosting] = []
        
        for posting in postingsWithValue {
            var accountBalance = newBalance[posting.account] ?? [:]
            let value = try posting.value!.evaluate(lookup: get)
            guard case .amount(let amount) = value else {
                throw "Posting value evaluates to a non-amount"
            }
            total[amount.commodity, or: 0] += amount.number
            accountBalance[amount.commodity, or: 0] += amount.number
            newBalance[posting.account] = accountBalance
            evaluatedPostings.append(EvaluatedPosting(account: posting.account, amount: amount))
        }
        
        if let postingWithoutValue = postingsWithoutValue.first {
            for (commodity, value) in total {
                let amount = Amount(number: -value, commodity: commodity)
                newBalance[postingWithoutValue.account, or: [:]][commodity, or: 0] += amount.number
                evaluatedPostings.append(EvaluatedPosting(account: postingWithoutValue.account, amount: amount))
                total[commodity, or: 0] += amount.number
            }
        }
        
        for evaluatedPosting in evaluatedPostings {
            for automatedTransaction in automatedTransactions {
                if try evaluatedPosting.match(expression: automatedTransaction.expression) {
                    for automatedPosting in automatedTransaction.postings {
                        let value = try automatedPosting.value.evaluate(lookup: self.get)
                        guard case .amount(let amount) = value else {
                            throw "Posting value evaluates to a non-amount"
                        }
                        total[amount.commodity, or: 0] += amount.number
                        newBalance[automatedPosting.account, or: [:]][amount.commodity, or: 0] += amount.number
                    }
                }
            }
        }
        
        for (commodity, value) in total {
            guard value == 0 else { throw "Postings of commodity \(commodity) not balanced: \(value)" }
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

    func expressionContext(name: String) -> Value? {

        switch name {
        case "year": return self.year.map { .amount(Amount(number: LedgerDouble($0))) }
        default:
            return get(definition: name)
        }
    }

}

struct EvaluatedPosting {
    var account: String
    var amount: Amount
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
        let expression = Expression.infix(operator: "=~", lhs: .string("Assets:Giro"), rhs: .regex("Gir"))
        XCTAssertTrue(try! expression.evaluate() == .bool(true))
    }

    func testPostingVariables() {
        let posting = EvaluatedPosting(account: "Assets:Giro", amount: Amount(number: 100, commodity: "EUR"))
        XCTAssertTrue(posting.expressionContext(name: "account") == .string("Assets:Giro"))

    }

    func testBool() {
        let e: (Expression) -> Value = { try! $0.evaluate(lookup: { _ in nil }) }
        XCTAssert(e(.infix(operator: "&&", lhs: .bool(true), rhs: .bool(true))) == .bool(true))
        XCTAssert(e(.infix(operator: "&&", lhs: .bool(true), rhs: .bool(false))) == .bool(false))
        XCTAssert(e(.infix(operator: "||", lhs: .bool(false), rhs: .bool(true))) == .bool(true))
    }

    func testTransactionVariables() {
        let transaction = Transaction(date: Date(year: 2015, month: 1, day: 16), state: .cleared, title: "My Transaction", notes: [], postings: [])
        XCTAssertTrue(transaction.expressionContext(name: "year") == .amount(Amount(number: 2015)))
        XCTAssertTrue(transaction.expressionContext(name: "month") == .amount(Amount(number: 1)))
        XCTAssertTrue(transaction.expressionContext(name: "day") == .amount(Amount(number: 16)))

    }

    func testStateVariables() {
        let state = State(year: 2016, definitions: ["one": .string("Hello")], accounts: [], commodities: [], tags: [], balance: [:], automatedTransactions: [])
        XCTAssertTrue(state.expressionContext(name: "year") == .amount(Amount(number: 2016)))
        XCTAssertTrue(state.expressionContext(name: "one") == .string("Hello"))
    }
    
    func testAutomatedTransaction() {
        let auto = Statement.automated(AutomatedTransaction(expression: .bool(true), postings: [
            AutomatedPosting(account: "Foo", value: .amount(Amount(number: 50, commodity: Commodity("$")))),
            AutomatedPosting(account: "Bar", value: .amount(Amount(number: -50, commodity: Commodity("$")))),
        ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: Amount(number: 20, commodity: Commodity("$"))),
            Posting(account: "Cash"),
        ])
        var state = State()
        try! state.apply(auto)
        try! state.apply(.transaction(transaction))
        XCTAssert(state.balance(account: "Foo") == [Commodity("$"): 100])
        XCTAssert(state.balance(account: "Bar") == [Commodity("$"): -100])
        XCTAssert(state.balance(account: "Expenses:Food") == [Commodity("$"): 20])
        XCTAssert(state.balance(account: "Cash") == [Commodity("$"): -20])
    }

    
    // TODO: Auto transactions with postings that don't have commodities
    // TODO: Unbalanced auto transactions should throw
    // TODO: test that evaluating a posting falls back on the transaction variables, which falls back on the state variables
    // TODO: test that a posting without a year, but which has a year specified using the year directive has a valid `date` (maybe cerate an EvaluatedPosting)
    // TODO: test that a posting without an amount (auto-balanced amount) matches on something like commodity='EUR'

    // TODO: test and add > >= < <= operators
    // TODO: test and add
}
