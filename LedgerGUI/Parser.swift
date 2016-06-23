//
//  Parser.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 23/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation
import SwiftParsec

struct Date {
    let year: Int
    let month: Int
    let day: Int
}

func curry<A, B, C, D>(f: (A, B, C) -> D) -> A -> B -> C -> D {
    return { a in { b in { c in f(a, b, c) } } }
}

func curry<A, B, C>(f: (A, B) -> C) -> A -> B -> C {
    return { a in { b in f(a, b) } }
}

func pair<A,B>(x: A) -> (B) -> (A,B) {
    return { y in (x,y) }
}

extension Date: Equatable {}
func ==(lhs: Date, rhs: Date) -> Bool {
    return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
}

let naturalString = StringParser.digit.many1.map(String.init)
let naturalWithCommaString = (StringParser.digit <|> StringParser.character(",")).many1.map( { digitsAndCommas in String(digitsAndCommas.filter { $0 != "," }) })


let natural: GenericParser<String, (), Int> = naturalString.map { Int($0)! }

func monthDay(separator: Character) -> GenericParser<String, (), (Int, Int)> {
    let separatorInt = StringParser.character(separator) *> natural
    return GenericParser.lift2( { ($0, $1)} , parser1: separatorInt, parser2: separatorInt)
}

extension Date {
    static let parser:  GenericParser<String, (), Date> =
       { y in { m, d in Date(year: y, month: m, day: d) } } <^> natural <*> (monthDay("/") <|> monthDay("-"))
}

/// This eats up the whitespace after a parser (TODO it also eats up newlines)
func lexeme<A>(parser: GenericParser<String,(), A>) -> GenericParser<String, (), A> {
    return parser <* spaceWithoutNewline.many
}

func lexline<A>(parser: GenericParser<String,(), A>) -> GenericParser<String, (), A> {
    return parser <* StringParser.oneOf(" \t").many <* StringParser.newLine
}

let noNewline: GenericParser<String,(),Character> = StringParser.noneOf("\n\r") // TODO use real newline stuff
let spaceWithoutNewline: GenericParser<String,(),Character> = StringParser.character(" ")

let spacer = (spaceWithoutNewline *> spaceWithoutNewline) <|> StringParser.tab

let noteStart: StringParser = StringParser.character(";")
let trailingNoteStart = spacer *> noteStart
let noteBody = ({Note(String($0))} <^> noNewline.many)
let trailingNote = lexeme(trailingNoteStart) *> noteBody
let note = lexeme(noteStart) *> noteBody

let transactionCharacter = trailingNoteStart.notAhead *> noNewline

let transactionTitle: GenericParser<String, (), (Date, String)> =
  pair <^> lexeme(Date.parser) <*> (String.init <^> transactionCharacter.many)

let commodity: GenericParser<String, (), String> = StringParser.string("USD") <|> StringParser.string("EUR") <|> StringParser.string("$")
let double: GenericParser<String, (), LedgerDouble> = GenericParser.lift2( { x, fraction in // todo name x
    guard let fraction = fraction else { return Double(x)! }
    return Double("\(x).\(fraction)")!
}, parser1: naturalWithCommaString, parser2: (StringParser.character(".") *> naturalString).optional)

extension Character {
    
    func isMemberOfCharacterSet(set: NSCharacterSet) -> Bool {
        
        let normalized = String(self).precomposedStringWithCanonicalMapping
        let unicodes = normalized.unicodeScalars
        
        guard unicodes.count == 1 else { return false }
        
        return set.longCharacterIsMember(unicodes.first!.value)
        
    }
    
    var isSpace: Bool {
        return isMemberOfCharacterSet(.whitespaceCharacterSet())
    }
    
    var isNewlineOrSpace: Bool {
        return isMemberOfCharacterSet(.whitespaceAndNewlineCharacterSet())
    }
}

let noSpace: GenericParser<String, (), Character> = StringParser.satisfy { !$0.isNewlineOrSpace }
let singleSpace: GenericParser<String, (), Character> = (spaceWithoutNewline <* noSpace.lookAhead).attempt

let amount: GenericParser<String, (), Amount> =
    GenericParser.lift2({ Amount(number: $1, commodity: $0) }, parser1: lexeme(commodity), parser2: double) <|>
    GenericParser.lift2(Amount.init, parser1: lexeme(double), parser2: commodity)

let account = GenericParser.lift2({ String( [$0] + $1 ) }, parser1: noSpace, parser2: (noSpace <|> singleSpace).many)

let posting: GenericParser<String, (), Posting> = GenericParser.lift3(Posting.init, parser1: lexeme(account), parser2: amount.optional, parser3: trailingNote.optional)

let commentStart: GenericParser<String, (), Character> = StringParser.oneOf(";#%|*")

let comment: GenericParser<String, (), Note> = commentStart *> spaceWithoutNewline.many *> ( { Note(String($0)) } <^> noNewline.many)


enum PostingOrNote {
    case posting(Posting)
    case note(Note)
}

let buildTransaction = { (dateAndTitle: (Date,String), comment: Note?, items: [PostingOrNote]) -> Transaction in
    var transactionNotes: [Note] = []
    if let note = comment {
        transactionNotes.append(note)
    }
    var postings: [Posting] = []

    for postingOrNote in items {
        switch postingOrNote {
        case .posting(let posting):
            postings.append(posting)
        case .note(let note):
            if postings.isEmpty {
                transactionNotes.append(note)
            } else {
                postings[postings.count-1].notes.append(note)

            }

        }
    }

    return Transaction(date: dateAndTitle.0, title: dateAndTitle.1, notes: transactionNotes, postings: postings)
}

let postingOrNote = PostingOrNote.note <^> lexeme(note) <|> PostingOrNote.posting <^> lexeme(posting)

let transaction: GenericParser<String, (), Transaction> =
    GenericParser.lift3(buildTransaction, parser1: transactionTitle, parser2: lexline(trailingNote.optional), parser3: (spaceWithoutNewline.many1 *> postingOrNote).separatedBy1(StringParser.newLine))

typealias LedgerDouble = Double // TODO use infinite precision arithmetic

struct Amount {
    let number: LedgerDouble
    let commodity: String
    init(number: LedgerDouble, commodity: String) {
        self.number = number
        self.commodity = commodity
    }
}

extension Amount: Equatable {}

func ==(lhs: Amount, rhs: Amount) -> Bool {
    return lhs.commodity == rhs.commodity && lhs.number == rhs.number
}

struct Note {
    let comment: String
    init(_ comment: String) {
        self.comment = comment
    }
}

extension Note: Equatable {}

func ==(lhs: Note, rhs: Note) -> Bool {
    return lhs.comment == rhs.comment
}

struct Posting {
    var account: String
    var amount: Amount?
    var notes: [Note]
}

extension Posting {
    init(account: String, amount: Amount? = nil, note: Note? = nil) {
        self = Posting(account: account, amount: amount, notes: note.map { [$0] } ?? [])
    }
}

extension Posting: Equatable { }

func ==(lhs: Posting, rhs: Posting) -> Bool {
    return lhs.account == rhs.account && lhs.amount == rhs.amount
}

struct Transaction {
    var date: Date
    var title: String
    var notes: [Note]
    var postings: [Posting]
}

extension Transaction: Equatable { }
func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.date == rhs.date && lhs.title == rhs.title && lhs.notes == rhs.notes && lhs.postings == rhs.postings
}
