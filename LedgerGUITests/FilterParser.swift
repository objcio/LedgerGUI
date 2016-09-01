//
//  FilterParser.swift
//  LedgerGUI
//
//  Created by Florian on 08/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

enum FilterToken: Equatable {
    case year(Int)
    case month(Int)
    case other(String)
}

extension Filter {
    static func tokenize(_ string: String) -> [FilterToken] {
        let parser = token.separatedBy(spaceWithoutNewline.many1) <* FastParser.eof
        return (try? parser.run(sourceName: "", input: ImmutableCharacters(string: string.lowercased()))) ?? [.other(string)]
    }
    
    static func parse(_ string: String) -> [Filter] {
        let tokens = tokenize(string)
        var year: Int?
        var month: Int?
        var other: [String] = []
        for token in tokens {
            switch token {
            case .year(let value): year = value
            case .month(let value): month = value
            case .other(let value): other.append(value)
            }
        }
        var period: (EvaluatedDate, EvaluatedDate)?
        switch (year, month) {
        case let (year?, month?):
            let lastDayInMonth = 31 // TODO
            period = (EvaluatedDate(year: year, month: month, day: 1), EvaluatedDate(year: year, month: month, day: lastDayInMonth))
        case let (year?, _):
            period = (EvaluatedDate(year: year, month: 1, day: 1), EvaluatedDate(year: year, month: 12, day: 31)) // TODO
        case let (_, month?):
            let lastDayInMonth = 31 // TODO
            let year = Calendar.current.component(.year, from: Foundation.Date())
            period = (EvaluatedDate(year: year, month: month, day: 1), EvaluatedDate(year: year, month: month, day: lastDayInMonth))
        default: ()
        }
        var result = other.map { Filter.string ($0) }
        if let period = period {
            result.append(.period(from: period.0, to: period.1))
        }
        return result
    }
}

func ==(lhs: FilterToken, rhs: FilterToken) -> Bool {
    switch (lhs, rhs) {
    case let (.year(l), .year(r)): return l == r
    case let (.month(l), .month(r)): return l == r
    case let (.other(l), .other(r)): return l == r
    default: return false
    }
}

let year: GenericParser<ImmutableCharacters, (), FilterToken> = natural >>- { number in
    if number > 1900 && number < 2100 {
        return GenericParser(result: .year(number))
    }
    return GenericParser.fail("Not a year")
}

let months: [(String, Int)] = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    let enumeratedSymbols = Array(calendar.monthSymbols.enumerated()) + Array(calendar.shortMonthSymbols.enumerated())
    return enumeratedSymbols.map { idx, symbol in
        (symbol.lowercased(), idx + 1)
    }
}()

let month: GenericParser<ImmutableCharacters, (), FilterToken> = GenericParser.choice(months.map { month, number in
    string(month).attempt *> GenericParser(result: .month(number))
    })

let token: GenericParser<ImmutableCharacters, (), FilterToken> = year <|> month <|> ({ .other(String($0)) } <^> noSpace.many1)

