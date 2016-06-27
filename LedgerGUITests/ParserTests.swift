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

class ParserTests: XCTestCase {
    
    func testParser<A>(parser: GenericParser<String,(), A>, compare: (A, A) -> Bool, success: [(String, A)], failure: [String]) {
        for (d, expected) in success {
            let result = try! parser.run(sourceName: "", input: d)
            XCTAssertTrue(compare(result,expected), "Expected \(result) to be \(expected)")
        }
        for d in failure {
            XCTAssertNil(try? Date.parser.run(sourceName: "", input: d))
        }
    }
    
    func testParser<A: Equatable>(parser: GenericParser<String,(), A>, success: [(String, A)], failure: [String]) {
        for (d, expected) in success {
            do {
                let result = try parser.run(sourceName: "", input: d)
                XCTAssertEqual(result, expected)
            } catch {
                XCTFail("\(error)")
            }

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

    func testTransactionTitle() {
        let example = ("1985-01-16   An income transaction\n", (Date(year: 1985, month: 1, day: 16), "An income transaction"))
        testParser(transactionTitle, compare: ==, success: [example], failure: [])
    }
    
    func testAmount() {
        let example = [("$ 100.00", Amount(number: 100.0, commodity: "$")),
                       ("100.00$", Amount(number: 100.0, commodity: "$")),
                       ("100 USD", Amount(number: 100, commodity: "USD")),
                       ("1,000.00 EUR", Amount(number: 1000, commodity: "EUR")),
                       ]
        testParser(amount, success: example, failure: [])
    }
    
    func testPosting() {
        let example = [("Assets:PayPal  $ 123", Posting(account: "Assets:PayPal", amount: Amount(number: 123, commodity: "$"), note: nil)),
                       ("Girokonto  10.01 USD", Posting(account: "Girokonto", amount: Amount(number: 10.01, commodity: "USD"), note: nil)),
                       ("Assets:Giro Konto  10.01 USD", Posting(account: "Assets:Giro Konto", amount: Amount(number: 10.01, commodity: "USD"), note: nil)),
                       ("Something Else", Posting(account: "Something Else", amount: nil, note: nil)),
                       ("Something Else  ; with a note", Posting(account: "Something Else", amount: nil, note: Note("with a note")))
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
        let examples = [("; This is a comment\n2016-01-03", Note("This is a comment"))]
        testParser(comment, success: examples, failure: [])
    }
    
    func testTransaction() {
        let examples = [("2016/01/31 My Transaction\n Assets:PayPal  200 $",
            Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction", notes: [],
                                   postings: [
                                    Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$"), note: nil)
                                    ])),
            ("2016/01/31 My Transaction\n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction",  notes: [],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction \n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction ",  notes: [],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction ; not a comment\n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction ; not a comment", notes: [],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
                      ]
        
        testParser(transaction, success: examples, failure: [])
    }
    
    func testTransactionNotes() {
        let examples = [
            ("2016/01/31 My Transaction  ; a note\n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction", notes: [Note("a note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction\t; a note\n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction", notes: [Note("a note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction", notes: [Note("a note"), Note("another note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$")),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ("2016/01/31 My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $  ;paypal note\n     ;second paypal note\n Giro",
                Transaction(date: Date(year: 2016, month: 1, day: 31), title: "My Transaction", notes: [Note("a note"), Note("another note")],
                    postings: [
                        Posting(account: "Assets:PayPal", amount: Amount(number: 200, commodity: "$"), notes: [Note("paypal note"), Note("second paypal note")]),
                        Posting(account: "Giro", amount: nil)
                    ])),
            ]
        testParser(transaction, success: examples, failure: [])

    }
    
    func testPerformance() {
        let sample = "2016/01/31 My Transaction\t; a note\n ; another note\n Assets:PayPal  200 $  ;paypal note\n     ;second paypal note\n Giro 10 USD"
        let transactions = Array(count: 2, repeatedValue: sample).joinWithSeparator("\n\n")
        let parser = transaction.separatedBy(StringParser.newLine.many1)
        
        self.measureBlock {
            try! parser.run(sourceName: "", input: transactions)
        }
   
    }
    
 
}

