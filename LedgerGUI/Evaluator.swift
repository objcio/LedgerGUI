//
//  Evaluator.swift
//  LedgerGUI
//
//  Created by Florian on 30/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

extension String: ErrorProtocol {}


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

extension State {
    mutating func apply(_ statement: Statement) throws {
        do {
            switch statement {
            case .year(let year):
                self.year = year
            case .definition(let name, let expression):
                definitions[name] = try expression.evaluate(context: lookup)
            case .account(let name):
                accounts.insert(name)
            case .commodity(let name):
                commodities.insert(name)
            case .tag(let name):
                tags.insert(name)
            case .comment:
                break
            case .transaction(let transaction):
                let evaluatedTransaction = try transaction.evaluate(automatedTransactions: automatedTransactions, year: year, context: lookup)
                apply(transaction: evaluatedTransaction)
            case .automated(let autoTransaction):
                automatedTransactions.append(autoTransaction)
            }
        } catch {
            throw "Tried to evaluate statement: \(statement), got an error: \(error)"
        }

    }
    
    mutating func apply(transaction: EvaluatedTransaction) {
        for posting in transaction.postings {
            balance[posting.account, or: [:]][posting.amount.commodity, or: 0] += posting.amount.number
        }
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
    
    func lookup(variable name: String) -> Value? {
        return definitions[name]
    }
}


extension EvaluatedTransaction {
    func lookup(variable: String) -> Value? {
        switch variable {
        case "date":
            return .date(date)
        default:
            return nil
        }
    }
}

func ??(lhs: ExpressionContext, rhs: ExpressionContext) -> ExpressionContext {
    return { x in
        return lhs(x) ?? rhs(x)
    }
}


struct EvaluatedPosting {
    var account: String
    var amount: Amount
    var cost: Amount?
}

extension EvaluatedPosting {
    func expressionContext(name: String) -> Value? {
        switch name {
        case "account":
            return .string(self.account)
        case "commodity":
            return .string(amount.commodity.value ?? "")
        default:
            return nil
        }
    }
    
    func match(expression: Expression, context: ExpressionContext) throws -> Bool {
        let value = try expression.evaluate(context: expressionContext ?? context)
        guard case .bool(let result) = value else {
            throw "Expected boolean expression"
        }
        return result
    }
}

extension EvaluatedPosting: CustomStringConvertible {
    var description: String {
        let displayCost = cost == nil ? "" : "@@ \(cost!)"
        return "  \(account)  \(amount)\(displayCost)"
    }
}


enum Value: Equatable {
    case amount(Amount)
    case string(String)
    case regex(String)
    case bool(Bool)
    case date(EvaluatedDate)
}

func ==(lhs: Value, rhs: Value) -> Bool {
    switch (lhs,rhs) {
    case let (.amount(x), .amount(y)): return x == y
    case let (.string(x), .string(y)): return x == y
    case let (.regex(x), .regex(y)): return x == y
    case let (.bool(x), .bool(y)): return x == y
    case let (.date(x), .date(y)): return x == y
    default: return false
    }
}

typealias ExpressionContext = (String) -> Value?

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
        guard case let .regex(regex) = rhs else {
            throw "Right-hand side of regular expression match is not a regular expression"
        }
        guard let string = stringRepresentation else {
            throw "Cannot convert \(self) to string for reg-ex matching"
        }
        let range = NSRange(location: 0, length: (string as NSString).length)
        return try RegularExpression(pattern: regex, options: []).firstMatch(in: string, options: [], range: range) != nil
    }
    
    var stringRepresentation: String? {
        switch self {
        case .string(let string):
            return string
        case .date(let date):
            return date.string
        default:
            return nil
        }
    }
}

struct EvaluatedDate: Equatable {
    var year: Int
    var month: Int
    var day: Int
}

func ==(lhs: EvaluatedDate, rhs: EvaluatedDate) -> Bool {
    return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
}

extension EvaluatedDate {
    init(date: Date, year: Int?) throws {
        guard let year = date.year ?? year else {
            throw "No year specified for \(date)"
        }
        self.year = year
        self.month = date.month
        self.day = date.day
    }
    
    var string: String {
        return "\(year)/\(month)/\(day)"
    }
}


struct EvaluatedTransaction {
    var postings: [EvaluatedPosting]
    var date: EvaluatedDate
}

extension EvaluatedTransaction {
    var balance: [Commodity: LedgerDouble] {
        var result: [Commodity: LedgerDouble] = [:]
        for posting in postings {
            let amount = posting.cost ?? posting.amount
            result[amount.commodity, or: 0] += amount.number
        }
        return result
    }

    func verify() throws {
        if balance.count == 2 {
            // When there are two currencies, there is a special case: if they don't balance out to zero, and if they are of different signs, it's an implicit currency conversion
            let keys = Array(balance.keys)
            let firstAmount = balance[keys[0]]!
            let secondAmount = balance[keys[1]]!
            let implicitCurrencyConversion = firstAmount.isNegative != secondAmount.isNegative
            guard !implicitCurrencyConversion else { return }
        }
        
        for (commodity, value) in balance {
            // TODO: until we have a proper LedgerDouble
            guard abs(value) < 0.00000001 else { throw "Postings of commodity \(commodity) not balanced: \(value)\n\(self)" }
//            guard value == 0 else { throw "Postings of commodity \(commodity) not balanced: \(value)\n\(self)" }
        }
    }
    
    mutating func append(posting: Posting, context: ExpressionContext) throws {
        try postings.append(posting.evaluate(context: lookup ?? context))
    }
    
    mutating func apply(automatedTransaction: AutomatedTransaction, context: ExpressionContext) throws {
        let transactionLookup = lookup ?? context
        for evaluatedPosting in postings {
            guard try evaluatedPosting.match(expression: automatedTransaction.expression, context: transactionLookup) else { continue }
            for automatedPosting in automatedTransaction.postings {
                let value = try automatedPosting.value.evaluate(context: transactionLookup)
                guard case .amount(var amount) = value else { throw "Posting value evaluates to a non-amount" }
                if !amount.hasCommodity {
                    amount.commodity = evaluatedPosting.amount.commodity
                    amount.number *= evaluatedPosting.amount.number
                }
                postings.append(EvaluatedPosting(account: automatedPosting.account, amount: amount, cost: nil))
            }
        }
    }
}

extension EvaluatedTransaction: CustomStringConvertible {
    var description: String {
        let displayPostings = postings.map { $0.description }.joined(separator: "\n")
        return "\(date)\n\(displayPostings)"
    }
}





extension Posting {
    func evaluate(context: ExpressionContext) throws -> EvaluatedPosting {
        let value = try self.value!.evaluate(context: context)
        guard case .amount(let amount) = value else { throw "Posting value evaluates to a non-amount" }
        var costAmount: Amount? = nil
        if let cost = cost {
            switch cost.type {
            case .total:
                costAmount = cost.amount.matchingSign(ofAmount: amount)
            case .perUnit:
                fatalError() // TODO
            }
        }
        return EvaluatedPosting(account: account, amount: amount, cost: costAmount)
    }
}

extension Transaction {
    // TODO: refactor this? we are using two variables from State
    func evaluate(automatedTransactions: [AutomatedTransaction], year: Int?, context: ExpressionContext) throws -> EvaluatedTransaction {
        var postingsWithValue = postings
        let postingsWithoutValue = postingsWithValue.remove { $0.value == nil }
        var evaluatedTransaction = try EvaluatedTransaction(postings: [], date: EvaluatedDate(date: date, year: year))
        
        for posting in postingsWithValue {
            try evaluatedTransaction.append(posting: posting, context: context)
        }
        
        guard postingsWithoutValue.count <= 1 else { throw "More than one posting without value" }
        if let postingWithoutValue = postingsWithoutValue.first {
            for (commodity, value) in evaluatedTransaction.balance {
                let amount = Amount(number: -value, commodity: commodity)
                evaluatedTransaction.postings.append(EvaluatedPosting(account: postingWithoutValue.account, amount: amount, cost: nil))
            }
        }
        
        for automatedTransaction in automatedTransactions {
            try evaluatedTransaction.apply(automatedTransaction: automatedTransaction, context: context)
        }
        
        try evaluatedTransaction.verify()
        return evaluatedTransaction
    }
}

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

extension Expression {
    func evaluate(context: ExpressionContext = { _ in return nil }) throws -> Value {
        switch self {
        case .amount(let amount):
            return .amount(amount)
        case .infix(let op, let lhs, let rhs):
            let left = try lhs.evaluate(context: context)
            let right = try rhs.evaluate(context: context)
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
            case "==":
                return .bool(left == right)
            default:
                fatalError("Unknown operator: \(op)")
            }
            
        case .ident(let name):
            guard let value = context(name) else { throw "Variable \(name) not defined"}
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


