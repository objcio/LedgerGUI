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
        XCTAssert(state.lookup(variable: name) == .amount(amount))

        let amount2 = Amount(number: 3, commodity: "EUR")
        let directive2 = Statement.definition(name: name, expression: .amount(amount2))
        try! state.apply(directive2)
        XCTAssert(state.lookup(variable: name) == .amount(amount2))
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
        XCTAssert(try! Expression.ident("foo").evaluate(context: lookup) == amount)
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
        let e: (Expression) -> Value = { try! $0.evaluate(context: { _ in nil }) }
        XCTAssert(e(.infix(operator: "&&", lhs: .bool(true), rhs: .bool(true))) == .bool(true))
        XCTAssert(e(.infix(operator: "&&", lhs: .bool(true), rhs: .bool(false))) == .bool(false))
        XCTAssert(e(.infix(operator: "||", lhs: .bool(false), rhs: .bool(true))) == .bool(true))
    }

    func testTransactionVariables() {
        let date = EvaluatedDate(year: 2016, month: 1, day: 15)
        let transaction = EvaluatedTransaction(postings: [], date: date)
        XCTAssertTrue(transaction.lookup(variable: "date") == .date(date))
    }

    func testStateVariables() {
        let state = State(year: 2016, definitions: ["one": .string("Hello")], accounts: [], commodities: [], tags: [], balance: [:], automatedTransactions: [])
        XCTAssertTrue(state.lookup(variable: "year") == .amount(Amount(number: 2016)))
        XCTAssertTrue(state.lookup(variable: "one") == .string("Hello"))
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
    
    func testAutomatedTransactionAmountMultipliers() {
        let auto = Statement.automated(AutomatedTransaction(expression: .infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Food")), postings: [
            AutomatedPosting(account: "Foo", value: .amount(Amount(number: 0.4))),
            AutomatedPosting(account: "Bar", value: .amount(Amount(number: -0.4))),
            ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: Amount(number: 20, commodity: Commodity("$"))),
            Posting(account: "Cash"),
            ])
        var state = State()
        try! state.apply(auto)
        try! state.apply(.transaction(transaction))
        XCTAssert(state.balance(account: "Foo") == [Commodity("$"): 0.4*20])
        XCTAssert(state.balance(account: "Bar") == [Commodity("$"): -0.4*20])
        XCTAssert(state.balance(account: "Expenses:Food") == [Commodity("$"): 20])
        XCTAssert(state.balance(account: "Cash") == [Commodity("$"): -20])
    }
    
    func testAutomatedTransactionBalanceErrors() {
        let auto = Statement.automated(AutomatedTransaction(expression: .infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Food")), postings: [
            AutomatedPosting(account: "Foo", value: .amount(Amount(number: 0.4))),
            ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: Amount(number: 20, commodity: Commodity("$"))),
            Posting(account: "Cash", amount: Amount(number: 20, commodity: Commodity("$"))),
            ])
        var state = State()
        try! state.apply(auto)
        XCTAssertNil(try? state.apply(.transaction(transaction)))
    }
    
    func testAutomatedTransactionDate() {
        let is2016 = Expression.infix(operator: "=~", lhs: .ident("date"), rhs: .regex("2016"))
        let isFood = Expression.infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Food"))
        let expression = Expression.infix(operator: "&&", lhs: is2016, rhs: isFood)
        
        let auto = Statement.automated(AutomatedTransaction(expression: expression, postings: [
            AutomatedPosting(account: "Foo", value: .amount(Amount(number: 0.4))),
            AutomatedPosting(account: "Bar", value: .amount(Amount(number: -0.4)))
            ]))
        let transaction = Transaction(date: Date(year: 2016, month: 1, day: 15), state: nil, title: "KFC", notes: [], postings: [
            Posting(account: "Expenses:Food", amount: Amount(number: 20, commodity: Commodity("$"))),
            Posting(account: "Cash", amount: Amount(number: -20, commodity: Commodity("$"))),
            ])
        var state = State()
        try! state.apply(auto)
        try! state.apply(.transaction(transaction))
        print(state)
        XCTAssert(state.balance(account: "Foo") == [Commodity("$"): 0.4*20])
        XCTAssert(state.balance(account: "Bar") == [Commodity("$"): -0.4*20])
        XCTAssert(state.balance(account: "Expenses:Food") == [Commodity("$"): 20])
        XCTAssert(state.balance(account: "Cash") == [Commodity("$"): -20])

    }
    
    // TODO: test that a posting without an amount (auto-balanced amount) matches on something like commodity='EUR'

    // TODO: test and add > >= < <= operators
    // TODO: test and add
}
