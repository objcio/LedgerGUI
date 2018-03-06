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


extension Double {
    var euro: Amount {
        return Amount(LedgerDouble(self), commodity: Commodity("EUR"))
    }

    var usd: Amount {
        return Amount(LedgerDouble(self), commodity: Commodity("$"))
    }
}

extension MultiCommodityAmount: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (Commodity, LedgerDouble)...) {
        value = [:]
        for (commodity, number) in elements {
            value[commodity] = number
        }
    }
}

class EvaluatorTests: XCTestCase {
    func forceUnwrap(_ f: @autoclosure () throws -> (), file: String = #file, line: UInt = #line) {
        do {
            try f()
        } catch {
            print(error)
            XCTFail()
        }
    }
        
    func testYear() {
        var state = Ledger()
        try! state.apply(.year(2005))
        XCTAssert(state.year == 2005)
    }
    
    func testDefine() {
        let name = "exchange_rate"
        var state = Ledger()

        try! state.apply(.definition(name: name, expression: .amount(2.euro)))
        XCTAssert(state.lookup(variable: name) == .amount(2.euro))

        try! state.apply(.definition(name: name, expression: .amount(3.euro)))
        XCTAssert(state.lookup(variable: name) == .amount(3.euro))
    }
    
    func testAccount() {
        let name = "Some:Account"
        var state = Ledger()
        XCTAssertFalse(state.valid(account: name))
        try! state.apply(.account(name))
        XCTAssertTrue(state.valid(account: name))
    }
    
    func testCommodity() {
        let name = "EUR"
        var state = Ledger()
        XCTAssertFalse(state.valid(commodity: name))
        try! state.apply(.commodity(name))
        XCTAssertTrue(state.valid(commodity: name))
    }
    
    func testTag() {
        let name = "tag"
        var state = Ledger()
        XCTAssertFalse(state.valid(tag: name))
        try! state.apply(.tag(name))
        XCTAssertTrue(state.valid(tag: name))
    }
    
    func testEvaluateExpression() {
        let expression = Expression.infix(operator: "*", lhs: .amount(2.euro), rhs: .amount(Amount(3)))
        let result = try! expression.evaluate()
        XCTAssert(result == .amount(6.euro))
        
        let amount = Value.amount(Amount(3))
        let lookup: (String) -> Value? = { if $0 == "foo" { return amount } else { return nil } }
        XCTAssert(try! Expression.ident("foo").evaluate(context: lookup) == amount)
    }
    
    func testAmountMultiplication() {
        let a1 = Amount(3)
        let a2 = Amount(5)
        let a3 = 7.euro
        let a4 = 11.usd
        XCTAssertTrue(try! a1.op(*, a2) == Amount(15))
        XCTAssertTrue(try! a1.op(*, a3) == 21.euro)
        XCTAssertTrue(try! a4.op(*, a2) == 55.usd)
        XCTAssertNil(try? a3.op(*, a4))
    }
    
    func testTransaction() {
        var state = Ledger()
        let date = LedgerGUI.Date(year: 2015, month: 1, day: 16)
        let posting1 = Posting(account: "Giro", amount: Amount(100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let posting2 = Posting(account: "Cash", amount: Amount(-100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let transaction = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2]))
        try! state.apply(transaction)
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 100])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -100])
        try! state.apply(transaction)
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 200])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -200])
    }
    
    func testAutoBalancing() {
        var state = Ledger()
        let date = LedgerGUI.Date(year: 2015, month: 1, day: 16)
        let posting1 = Posting(account: "Giro", amount: Amount(100, commodity: "USD"))
        let posting2 = Posting(account: "Cash", value: nil)
        let posting3 = Posting(account: "Giro", amount: 200.euro)
        
        try! state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2])))
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 100])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -100])
        
        state = Ledger()
        try! state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting1, posting2])))
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 200])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -200])
        
        state = Ledger()
        try! state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2, posting3])))
        XCTAssert(state.balance(account: "Giro") == [Commodity("USD"): 100, Commodity("EUR"): 200])
        XCTAssert(state.balance(account: "Cash") == [Commodity("USD"): -100, Commodity("EUR"): -200])
        
        XCTAssertNil(try? state.apply(.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2, posting2]))))
    }
    
    func testBalanceVerification() {
        var state = Ledger()
        let date = LedgerGUI.Date(year: 2015, month: 1, day: 16)
        let posting1 = Posting(account: "Giro", amount: Amount(100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let posting2 = Posting(account: "Cash", amount: Amount(-200, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let transaction = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting2]))
        XCTAssertNil(try? state.apply(transaction))

        let posting3 = Posting(account: "Giro", amount: Amount(100, commodity: "USD"), cost: nil, balance: nil, note: nil)
        let posting4 = Posting(account: "Cash", amount: (-100).euro, cost: nil, balance: nil, note: nil)
        let transaction2 = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting3, posting4]))
        XCTAssertNotNil(try? state.apply(transaction2))
        
        let transaction3 = Statement.transaction(Transaction(date: date, state: nil, title: "My Transaction", notes: [], postings: [posting1, posting1, posting2]))
        XCTAssertNotNil(try? state.apply(transaction3))
    }
    
    func testRegex() {
        let expression = Expression.infix(operator: "=~", lhs: .string("Assets:Giro"), rhs: .regex("Gir"))
        XCTAssertTrue(try! expression.evaluate() == .bool(true))
    }

    func testPostingVariables() {
        let posting = EvaluatedPosting(account: "Assets:Giro", amount: 100.euro, cost: nil, virtual: false)
        XCTAssertTrue(posting.expressionContext(name: "account") == .string("Assets:Giro"))

    }

    func testBool() {
        let e: (Expression) -> Value = { try! $0.evaluate(context: { _ in nil }) }
        XCTAssert(e(.infix(operator: "&&", lhs: .bool(true), rhs: .bool(true))) == .bool(true))
        XCTAssert(e(.infix(operator: "&&", lhs: .bool(true), rhs: .bool(false))) == .bool(false))
        XCTAssert(e(.infix(operator: "||", lhs: .bool(false), rhs: .bool(true))) == .bool(true))
    }

    func testTransactionVariables() {
        let date = EvaluatedDate(year: 2016, month: 1, day: 15)
        let transaction = EvaluatedTransaction(title: "", postings: [], date: date)
        XCTAssertTrue(transaction.lookup(variable: "date") == .date(date))
    }

    func testStateVariables() {
        let state = Ledger(year: 2016, definitions: ["one": .string("Hello")], accounts: [], commodities: [], tags: [], balance: [:], automatedTransactions: [], evaluatedTransactions: [])
        XCTAssertTrue(state.lookup(variable: "one") == .string("Hello"))
    }
    
    func testAutomatedTransaction() {
        let auto = Statement.automated(AutomatedTransaction(expression: .bool(true), postings: [
            AutomatedPosting(account: "Foo", value: .amount(50.usd), virtual: false),
            AutomatedPosting(account: "Bar", value: .amount((-50).usd), virtual: false),
        ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: 20.usd),
            Posting(account: "Cash"),
        ])
        var state = Ledger()
        try! state.apply(auto)
        try! state.apply(.transaction(transaction))
        XCTAssert(state.balance(account: "Foo") == [Commodity("$"): 100])
        XCTAssert(state.balance(account: "Bar") == [Commodity("$"): -100])
        XCTAssert(state.balance(account: "Expenses:Food") == [Commodity("$"): 20])
        XCTAssert(state.balance(account: "Cash") == [Commodity("$"): -20])
    }
    
    func testAutomatedTransactionAmountMultipliers() {
        let auto = Statement.automated(AutomatedTransaction(expression: .infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Food")), postings: [
            AutomatedPosting(account: "Foo", value: .amount(Amount(0.4)), virtual: false),
            AutomatedPosting(account: "Bar", value: .amount(Amount(-0.4)), virtual: false),
            ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: 20.usd),
            Posting(account: "Cash"),
            ])
        var state = Ledger()
        try! state.apply(auto)
        try! state.apply(.transaction(transaction))
        XCTAssert(state.balance(account: "Foo") == [Commodity("$"): LedgerDouble(0.4*20)])
        XCTAssert(state.balance(account: "Bar") == [Commodity("$"): LedgerDouble(-0.4*20)])
        XCTAssert(state.balance(account: "Expenses:Food") == [Commodity("$"): 20])
        XCTAssert(state.balance(account: "Cash") == [Commodity("$"): -20])
    }
    
    func testAutomatedTransactionBalanceErrors() {
        let auto = Statement.automated(AutomatedTransaction(expression: .infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Food")), postings: [
            AutomatedPosting(account: "Foo", value: .amount(Amount(0.4)), virtual: false),
            ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: 20.usd),
            Posting(account: "Cash", amount: 20.usd),
            ])
        var state = Ledger()
        try! state.apply(auto)
        XCTAssertNil(try? state.apply(.transaction(transaction)))
    }
    
    func testAutomatedTransactionDate() {
        let is2016 = Expression.infix(operator: "=~", lhs: .ident("date"), rhs: .regex("2016"))
        let isFood = Expression.infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Food"))
        let expression = Expression.infix(operator: "&&", lhs: is2016, rhs: isFood)
        
        let auto = Statement.automated(AutomatedTransaction(expression: expression, postings: [
            AutomatedPosting(account: "Foo", value: .amount(Amount(0.4)), virtual: false),
            AutomatedPosting(account: "Bar", value: .amount(Amount(-0.4)), virtual: false)
            ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: 20.usd),
            Posting(account: "Cash", amount: (-20).usd),
            ])
        var state = Ledger()
        try! state.apply(auto)
        try! state.apply(.transaction(transaction))
        XCTAssert(state.balance(account: "Foo") == [Commodity("$"): LedgerDouble(0.4*20)])
        XCTAssert(state.balance(account: "Bar") == [Commodity("$"): LedgerDouble(-0.4*20)])
        XCTAssert(state.balance(account: "Expenses:Food") == [Commodity("$"): 20])
        XCTAssert(state.balance(account: "Cash") == [Commodity("$"): -20])
    }
    
    func testPostingCosts() {
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "Foo", notes: [], postings: [
            Posting(account: "Assets:Giro", amount: 10.euro, cost: Cost(type: .total, amount: 12.usd)),
            Posting(account: "Assets:Paypal", amount: (-12).usd),
        ])
        var state = Ledger()
        try! state.apply(.transaction(transaction))
        XCTAssert(state.balance(account: "Assets:Giro") == [Commodity("EUR"): 10])
        XCTAssert(state.balance(account: "Assets:Paypal") == [Commodity("$"): -12])
        
        let transaction2 = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "Foo", notes: [], postings: [
            Posting(account: "Assets:Giro", amount: 10.euro, cost: Cost(type: .total, amount: 12.usd)),
            Posting(account: "Assets:Paypal"),
        ])
        var state2 = Ledger()
        try! state2.apply(.transaction(transaction2))
        XCTAssert(state2.balance(account: "Assets:Giro") == [Commodity("EUR"): 10])
        XCTAssert(state2.balance(account: "Assets:Paypal") == [Commodity("$"): -12])
        
        let transaction3 = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "Foo", notes: [], postings: [
            Posting(account: "Assets:Giro", amount: (-10).euro, cost: Cost(type: .total, amount: 12.usd)),
            Posting(account: "Assets:Paypal", amount: 12.usd),
            ])
        var state3 = Ledger()
        try! state3.apply(.transaction(transaction3))
        XCTAssert(state3.balance(account: "Assets:Giro") == [Commodity("EUR"): -10])
        XCTAssert(state3.balance(account: "Assets:Paypal") == [Commodity("$"): 12])
    }
    
    func testImplicitConversion() {
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "Foo", notes: [], postings: [
            Posting(account: "Assets:Giro", amount: 10.euro),
            Posting(account: "Assets:Paypal", amount: (-12).usd),
            ])
        var state = Ledger()
        try! state.apply(.transaction(transaction))
        XCTAssert(state.balance(account: "Assets:Giro") == [Commodity("EUR"): 10])
        XCTAssert(state.balance(account: "Assets:Paypal") == [Commodity("$"): -12])
    }
    
    func testSample() {
        typealias MyParser = FastParser
        let path = Bundle(for: ParserTests.self).path(forResource: "sample", ofType: "txt")!
        let contents = try! String(contentsOfFile: path)
        let statements = parse(string: contents)
        var state = Ledger()
        for statement in statements {
            forceUnwrap(try state.apply(statement))
        }
        let result = Array(state.balance).sorted { p1, p2 in
            return p1.key < p2.key
        }
        for x in result {
            print (x)
        }
    }

    // TODO: test virtual postings
    // TODO: test cost expressions
    // TODO: test that a posting without an amount (auto-balanced amount) matches on something like commodity='EUR'
    // TODO: test and add > >= < <= operators
}
