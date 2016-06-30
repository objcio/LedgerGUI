//
//  Evaluator.swift
//  LedgerGUI
//
//  Created by Florian on 30/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

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
