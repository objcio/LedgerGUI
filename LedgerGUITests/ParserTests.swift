//
//  LedgerGUITests.swift
//  LedgerGUITests
//
//  Created by Florian on 22/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import XCTest
@testable import LedgerGUI

class ParserTests: XCTestCase {
    
    func testParser<A>(_ parser: GenericParser<String,(), A>, compare: (A, A) -> Bool, success: [(String, A)], failure: [String]) {
        for (d, expected) in success {
            let result = try! parser.run(sourceName: "", input: d)
            XCTAssertTrue(compare(result,expected), "Expected \(result) to be \(expected)")
        }
        for d in failure {
            XCTAssertNil(try? (parser <* StringParser.eof).run(sourceName: "", input: d))
        }
    }
    
    func testParser<A: Equatable>(_ parser: GenericParser<String,(), A>, success: [(String, A)], failure: [String], file: String = #file, line: UInt = #line) {
        for (d, expected) in success {
            do {
                let result = try parser.run(sourceName: "", input: d)
                if result != expected {
                    self.recordFailure(withDescription: "Expected \(expected), but got \(result)", inFile: file, atLine: line, expected: true)
                }
            } catch {
                XCTFail("\(error)")
            }

        }
        for d in failure {
            XCTAssertNil(try? (parser <* StringParser.eof).run(sourceName: "", input: d))
        }
    }
    
    func testDates() {
        let dates = [("2016/06/21", Date(year: 2016, month: 6, day: 21)),
                     ("14-1-31", Date(year: 14, month: 1, day: 31)),
                     ("16-01", Date(year: nil, month: 16, day: 1)),
                     ("16/01", Date(year: nil, month: 16, day: 1))
                     ]
        let failingDates = ["2016/06-21"]
        testParser(Date.parser, success: dates , failure: failingDates)
    }

    func testAmount() {
        let example = [("$ 100.00", Amount(number: 100.0, commodity: "$")),
                       ("100.00$", Amount(number: 100.0, commodity: "$")),
                       ("100 USD", Amount(number: 100, commodity: "USD")),
                       ("1,000.00 EUR", Amount(number: 1000, commodity: "EUR")),
//                       ("-$100", Amount(number: -100, commodity: "$")),
//                       ("- 100 EUR", Amount(number: -100, commodity: "EUR"))
                       ]
        testParser(amount, success: example, failure: [])
    }
    
    func testPosting() {
        let example: [(String,Posting)] = [
            ("Assets:PayPal  $ 123", Posting(account: "Assets:PayPal", amount: Amount(number: 123, commodity: "$"), balance: nil, note: nil)),
            ("Girokonto  10.01 USD", Posting(account: "Girokonto", amount: Amount(number: 10.01, commodity: "USD"), balance: nil, note: nil)),
            ("Assets:Giro Konto  10.01 USD", Posting(account: "Assets:Giro Konto", amount: Amount(number: 10.01, commodity: "USD"), note: nil)),
            ("Something Else", Posting(account: "Something Else", amount: nil, note: nil)),
            ("Something Else  ; with a note", Posting(account: "Something Else", amount: nil, note: Note("with a note"))),
            ("Balance  -100 EUR = 0", Posting(account: "Balance", amount: Amount(number: -100, commodity: "EUR"), balance: Amount(number: 0, commodity: nil), note: nil)),
            ("Assets:Brokerage  10 USD @ 0.83 EUR", Posting(account: "Assets:Brokerage", amount: Amount(number: 10, commodity: "USD"), cost: Cost(type: .perUnit, amount: Amount(number: 0.83, commodity: "EUR")), balance: nil, note: nil)),
            ("Assets:Brokerage  10 USD @@ 8.33 EUR", Posting(account: "Assets:Brokerage", amount: Amount(number: 10, commodity: "USD"), cost: Cost(type: .total, amount: Amount(number: 8.33, commodity: "EUR")), balance: nil, note: nil)),
            ("Liabilities:VAT  (10.0 USD * 2)", Posting(account: "Liabilities:VAT", expression: Expression.infix(operator: "*", lhs: .amount(Amount(number: 10, commodity: "USD")), rhs: .amount(Amount(number: 2, commodity: nil))), cost: nil, balance: nil, notes: [])),
            ("Test\t\t123", Posting(account: "Test", amount: Amount(number: 123)))

            ]
        testParser(posting, success: example, failure: [])
    }
    
    func testAccount() {
        let example = [("Payp:x test", "Payp:x test"),
                       ("Paypal:Test  Hello", "Paypal:Test")
                      ]
        let failures = [" Paypal"]
        
        testParser(account, success: example, failure: failures)
    }
    
    func testComment() {
        let examples = [
            ("; This is a comment\n2016-01-03", "This is a comment"),
            ("# This is a comment\n2016-01-03", "This is a comment")
        ]
        testParser(comment, success: examples, failure: [])
    }
    
    func testTransaction() {
        let examples = [("2016/01/31 My Transaction\n Assets:PayPal  200 $",
                         Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction", notes: [],
                                   postings: [
                                    Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$"), note: nil)
                                    ])),
            ("2016/01/31 My Transaction\n Assets:PayPal  200 $\n Giro",
             Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction",  notes: [],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction \n Assets:PayPal  200 $\n Giro",
             Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction ",  notes: [],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction ; not a comment\n Assets:PayPal  200 $\n Giro",
             Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction ; not a comment", notes: [],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction ; not a comment\n Assets:PayPal  200\n Giro",
             Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction ; not a comment", notes: [],
                         postings: [
                            Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: nil)),
                            Posting(account: "Giro", amount: nil)
                ])),
                      ]
        
        testParser(transaction, success: examples, failure: [])
    }
    
    func testTransactionNotes() {
        let examples = [
            ("2016/01/31 My Transaction  ; a note\n Assets:PayPal  200 $\n Giro",
             Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction", notes: [Note("a note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction\t; a note\n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil,  title: "My Transaction", notes: [Note("a note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction", notes: [Note("a note"), Note("another note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $  ;paypal note\n     ;second paypal note\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), state: nil, title: "My Transaction", notes: [Note("a note"), Note("another note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$"), cost: nil, balance: nil, notes: [Note("paypal note"), Note("second paypal note")]),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 * My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $  ;paypal note\n     ;second paypal note\n Giro",
             Transaction(date: Date(year: 2016, month: 1, day: 31), state: .cleared, title: "My Transaction", notes: [Note("a note"), Note("another note")],
                         postings: [
                            Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$"), cost: nil, balance: nil, notes: [Note("paypal note"), Note("second paypal note")]),
                            Posting(account: "Giro", amount: nil)
                ])),
            ("2016/01/31 ! My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $  ;paypal note\n     ;second paypal note\n Giro",
             Transaction(date: Date(year: 2016, month: 1, day: 31), state: .pending, title: "My Transaction",  notes: [Note("a note"), Note("another note")],
                         postings: [
                            Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$"), cost: nil, balance: nil, notes: [Note("paypal note"), Note("second paypal note")]),
                            Posting(account: "Giro", amount: nil)
                ])),
            ]
        testParser(transaction, success: examples, failure: [])

    }
    
    func testAccountDirective() {
        let sample = [("account Expenses:Food", Statement.account("Expenses:Food"))]
        testParser(accountDirective, success: sample, failure: [])
    }

    func testPerformance() {
        let sample = "2016/01/31 My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $  ;paypal note\n     ;second paypal note\n Giro  10 USD"
        let transactions = Array(repeating: sample, count: 5).joined(separator: "\n")
        let parser = transaction.separatedBy(StringParser.newLine.many1)
        
        self.measure {
            try! parser.run(sourceName: "", input: transactions)
        }
   
    }
    
    func testExpression() {
        let sample = [
            ("(1 * 5 + 2)", Expression.infix(operator: "+", lhs: .infix(operator: "*", lhs: .amount(Amount(number: 1)), rhs: .amount(Amount(number: 5))), rhs: .amount(Amount(number: 2)))),
            ("(3 / 7 USD)", Expression.infix(operator: "/", lhs: .amount(Amount(number: 3)), rhs: .amount(Amount(number: 7, commodity: "USD")))),
            ("true", Expression.ident("true")),
            ("account =~ /^Test$/", Expression.infix(operator: "=~", lhs: .ident("account"), rhs: .regex("^Test$"))),
            ("account == test && hello =~ true", Expression.infix(operator: "&&", lhs: .infix(operator: "==", lhs: .ident("account"), rhs: .ident("test")), rhs: .infix(operator: "=~", lhs: .ident("hello"), rhs: .ident("true")))),
            ("account =~ /Income:Core Data/ && commodity == \"EUR\"", Expression.infix(operator: "&&", lhs: .infix(operator: "=~", lhs: .ident("account"), rhs: .regex("Income:Core Data")), rhs: .infix(operator: "==", lhs: .ident("commodity"), rhs: .string("EUR"))))
            ]
        testParser(expression, success: sample, failure: [])
    }

    func testAutomatedTransaction() {
        let sample: [(String,AutomatedTransaction)] = [
            ("= expr 'true'\n  [Funds:Core Data]  -0.7\n  [Assets:Giro]  0.7",
            AutomatedTransaction(type: .expr(.ident("true")), postings: [
                Posting(account: "[Funds:Core Data]", amount: Amount(number: -0.7, commodity: nil)),
                Posting(account: "[Assets:Giro]", amount: Amount(number: 0.7, commodity: nil))
            ])),
            ("= /Expenses:Functional Swift/\n  [Assets:Giro]  1\n  [Funds:Functional Swift]  -1",
             AutomatedTransaction(type: .regex("Expenses:Functional Swift"), postings: [
                Posting(account: "[Assets:Giro]", amount: Amount(number: 1, commodity: nil)),
                Posting(account: "[Funds:Functional Swift]", amount: Amount(number: -1, commodity: nil))
                ])
            ),
        ]
        testParser(automatedTransaction, success: sample, failure: [])
    }

    func testDefine() {
        let sample: [(String,Statement)] = [
            ("define exchange_rate=100.00/99.00 EUR", .definition(name: "exchange_rate", expression: .infix(operator: "/", lhs: .amount(Amount(number: 100)), rhs: .amount(Amount(number: 99, commodity: "EUR")))))
        ]
        testParser(definition, success: sample, failure: [])

    }

    func testTag() {
        let sample: [(String, Statement)] = [
            ("tag file", .tag("file"))
        ]
        testParser(tag, success: sample, failure: [])
    }

    func testFile() {
        let path = Bundle(for: ParserTests.self).pathForResource("sample", ofType: "txt")!
        let contents = try! String(contentsOfFile: path)
        let parts = contents.components(separatedBy: "\n\n")
        let parser = StringParser.newLine.many *> statements <* StringParser.space.many <* StringParser.eof
        let result: [Statement] = parts.flatMap { (s: String) -> [Statement] in
            try! parser.run(sourceName: "sample.txt", input: s + "\n")
        }
//            let result = try! parser.run(sourceName: "sample.txt", input: contents)
        print(result)
    }
 
}

