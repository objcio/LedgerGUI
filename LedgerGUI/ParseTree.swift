//
//  ParseTree.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 27/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

struct Date: Equatable {
    let year: Int?
    let month: Int
    let day: Int
}

func ==(lhs: Date, rhs: Date) -> Bool {
    return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
}

enum TransactionState: Character {
    case cleared = "*"
    case pending = "!"
}

extension TransactionState: Equatable { }

enum PostingOrNote {
    case posting(Posting)
    case note(Note)
}

struct Commodity: Equatable, Hashable {
    var value: String?
    
    var hashValue: Int {
        return value?.hashValue ?? 0
    }
    
    init(_ value: String? = nil) {
        self.value = value
    }
}

func ==(x: Commodity, y: Commodity) -> Bool {
    return x.value == y.value
}

extension Commodity: CustomStringConvertible {
    var description: String {
        return value ?? ""
    }
}


extension Transaction {
    init(dateStateAndTitle: (Date, TransactionState?, String), comment: Note?, items: [PostingOrNote]) {
        var transactionNotes: [Note] = []
        var postings: [Posting] = []
        
        if let note = comment {
            transactionNotes.append(note)
        }
        
        for postingOrNote in items {
            switch postingOrNote {
            case .posting(let posting):
                postings.append(posting)
            case .note(let note) where postings.isEmpty:
                transactionNotes.append(note)
            case .note(let note):
                postings[postings.count-1].notes.append(note)
            }
        }
        
        self = Transaction(date: dateStateAndTitle.0, state: dateStateAndTitle.1, title: dateStateAndTitle.2, notes: transactionNotes, postings: postings)
    }
}

struct Amount: Equatable {
    var number: LedgerDouble
    var commodity: Commodity
    init(_ number: LedgerDouble, commodity: Commodity = Commodity()) {
        self.number = number
        self.commodity = commodity
    }
    
    var hasCommodity: Bool {
        return commodity.value != nil
    }
}

func ==(lhs: Amount, rhs: Amount) -> Bool {
    return lhs.commodity == rhs.commodity && lhs.number == rhs.number
}

extension Amount {
    var isNegative: Bool {
        return number.isNegative
    }
    
    func matchingSign(ofAmount otherAmount: Amount) -> Amount {
        guard isNegative != otherAmount.isNegative else { return self }
        return Amount(number * -1, commodity: commodity)
    }
}

extension Amount: CustomStringConvertible {
    var description: String {
        return "\(number.value)\(commodity)"
    }
}


struct Note: Equatable {
    let comment: String
    init(_ comment: String) {
        self.comment = comment
    }
}

func ==(lhs: Note, rhs: Note) -> Bool {
    return lhs.comment == rhs.comment
}


struct Cost: Equatable {
    enum CostType: String, Equatable {
        case total = "@@"
        case perUnit = "@"
    }
    var type: CostType
    var amount: Amount
}

func ==(lhs: Cost, rhs: Cost) -> Bool {
    return lhs.type == rhs.type && lhs.amount == rhs.amount
}

extension Cost: CustomStringConvertible {
    var description: String {
        return "\(type.rawValue) \(amount)"
    }
}



struct Posting: Equatable {
    var account: String
    var value: Expression?
    var cost: Cost?
    var balance: Amount?
    var virtual: Bool
    var notes: [Note]
}

func ==(lhs: Posting, rhs: Posting) -> Bool {
    return lhs.account == rhs.account && lhs.value == rhs.value && lhs.cost == rhs.cost && lhs.balance == rhs.balance && lhs.notes == rhs.notes && lhs.virtual == rhs.virtual
}

extension Posting {
    init(account: String, amount: Amount, cost: Cost? = nil, balance: Amount? = nil, virtual: Bool = false, note: Note? = nil) {
        self = Posting(account: account, value: .amount(amount), cost: cost, balance: balance, virtual: virtual, notes: note.map { [$0] } ?? [])
    }
    
    init(account: String, value: Expression? = nil, cost: Cost? = nil, balance: Amount? = nil, virtual: Bool = false, note: Note? = nil) {
        self = Posting(account: account, value: value, cost: cost, balance: balance, virtual: virtual, notes: note.map { [$0] } ?? [])
    }

    init(account: (String, Bool), value: Expression? = nil, cost: Cost? = nil, balance: Amount? = nil, note: Note? = nil) {
        self = Posting(account: account.0, value: value, cost: cost, balance: balance, virtual: account.1, notes: note.map { [$0] } ?? [])
    }
}


struct AutomatedPosting: Equatable {
    var account: String
    var value: Expression
    var virtual: Bool
}

extension AutomatedPosting {
    init(account: (String, Bool), value: Expression) {
        self.account = account.0
        self.value = value
        self.virtual = account.1
    }
}

func ==(lhs: AutomatedPosting, rhs: AutomatedPosting) -> Bool {
    return lhs.account == rhs.account && lhs.value == rhs.value && lhs.virtual == rhs.virtual
}



struct Transaction: Equatable {
    var date: Date
    var state: TransactionState?
    var title: String
    var notes: [Note]
    var postings: [Posting]
}

func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.date == rhs.date && lhs.state == rhs.state && lhs.title == rhs.title && lhs.notes == rhs.notes && lhs.postings == rhs.postings
}


indirect enum Expression: Equatable {
    case infix(`operator`: String, lhs: Expression, rhs: Expression)
    case amount(Amount)
    case bool(Bool)
    case ident(String)
    case regex(String)
    case string(String)
}

func ==(lhs: Expression, rhs: Expression) -> Bool {
    switch (lhs, rhs) {
    case let (.infix(op1, lhs1, rhs1), .infix(op2, lhs2, rhs2)) where op1 == op2 && lhs1 == lhs2 && rhs1 == rhs2:
        return true
    case let(.amount(x), .amount(y)) where x == y: return true
    case let(.ident(x), .ident(y)) where x == y: return true
    case let(.regex(x), .regex(y)) where x == y: return true
    case let(.string(x), .string(y)) where x == y: return true
    case let(.bool(x), .bool(y)) where x == y: return true
    default: return false
    }
}


struct AutomatedTransaction: Equatable {
    var expression: Expression
    var postings: [AutomatedPosting]
}

func ==(lhs: AutomatedTransaction, rhs: AutomatedTransaction) -> Bool {
    return lhs.expression == rhs.expression && lhs.postings == rhs.postings
}


enum Statement: Equatable {
    case definition(name: String, expression: Expression)
    case tag(String)
    case account(String)
    case automated(AutomatedTransaction)
    case transaction(Transaction)
    case comment(String)
    case commodity(String)
    case year(Int)
}

func ==(lhs: Statement, rhs: Statement) -> Bool {
    switch (lhs, rhs) {
    case let (.definition(ln, le), .definition(rn, re)): return ln == rn && le == re
    case let (.tag(l), .tag(r)): return l == r
    case let (.account(l), .account(r)): return l == r
    case let (.automated(l), .automated(r)): return l == r
    case let (.transaction(l), .transaction(r)): return l == r
    case let (.comment(l), .comment(r)): return l == r
    case let (.commodity(l), .commodity(r)): return l == r
    case let (.year(l), .year(r)): return l == r
        
    default: return false
    }
}

