//
//  Parser.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 23/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation



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

struct Amount {
    let number: LedgerDouble
    let commodity: String?
    init(number: LedgerDouble, commodity: String? = nil) {
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

enum AmountOrExpression: Equatable {
    case amount(Amount)
    case expression(Expression)
}

func ==(lhs: AmountOrExpression, rhs: AmountOrExpression) -> Bool {
    switch (lhs, rhs) {
    case let (.amount(l), .amount(r)):
        return l == r
    case let (.expression(l), .expression(r)):
        return l == r
    default: return false
    }
}

struct Posting {
    var account: String
    var amountOrExpression: AmountOrExpression?
    var cost: Cost?
    var balance: Amount?
    var notes: [Note]
}

extension Posting {
    init(account: String, amountOrExpression: AmountOrExpression? = nil, cost: Cost? = nil, balance: Amount? = nil, note: Note?) {
        self = Posting(account: account, amountOrExpression: amountOrExpression, cost: cost, balance: balance, notes: note.map { [$0] } ?? [])
    }

    init(account: String, expression: Expression? = nil, cost: Cost? = nil, balance: Amount? = nil, notes: [Note]) {
        self = Posting(account: account, amountOrExpression: expression.map(AmountOrExpression.expression), cost: cost, balance: balance, notes: notes)
    }

    init(account: String, amount: Amount? = nil, cost: Cost? = nil, balance: Amount? = nil, notes: [Note]) {
        self = Posting(account: account, amountOrExpression: amount.map(AmountOrExpression.amount), cost: cost, balance: balance, notes: notes)
    }
    init(account: String, amount: Amount? = nil, cost: Cost? = nil, balance: Amount? = nil, note: Note? = nil) {
        self = Posting(account: account, amount: amount, cost: cost, balance: balance, notes: note.map { [$0] } ?? [])
    }
}

extension Posting: Equatable { }

func ==(lhs: Posting, rhs: Posting) -> Bool {
    return lhs.account == rhs.account && lhs.amountOrExpression == rhs.amountOrExpression && lhs.cost == rhs.cost && lhs.balance == rhs.balance && lhs.notes == rhs.notes
}

struct Transaction {
    var date: Date
    var state: TransactionState?
    var title: String
    var notes: [Note]
    var postings: [Posting]
}

extension Transaction: Equatable { }
func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.date == rhs.date && lhs.state == rhs.state && lhs.title == rhs.title && lhs.notes == rhs.notes && lhs.postings == rhs.postings
}

func lift2<Param1, Param2, Result, StreamType, UserState>(_ function: (Param1, Param2) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift2(function, parser1: parser1, parser2: parser2)
}

func lift3<Param1, Param2, Param3, Result, StreamType, UserState>(_ function: (Param1, Param2, Param3) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>, _ parser3: GenericParser<StreamType, UserState, Param3>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift3(function, parser1: parser1, parser2: parser2, parser3: parser3)
}

func lift4<Param1, Param2, Param3, Param4, Result, StreamType, UserState>(_ function: (Param1, Param2, Param3, Param4) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>, _ parser3: GenericParser<StreamType, UserState, Param3>, _ parser4: GenericParser<StreamType, UserState, Param4>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift4(function, parser1: parser1, parser2: parser2, parser3: parser3, parser4: parser4)
}


func lift5<Param1, Param2, Param3, Param4, Param5, Result, StreamType, UserState>(_ function: (Param1, Param2, Param3, Param4, Param5) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>, _ parser3: GenericParser<StreamType, UserState, Param3>, _ parser4: GenericParser<StreamType, UserState, Param4>, _ parser5: GenericParser<StreamType, UserState, Param5>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift5(function, parser1: parser1, parser2: parser2, parser3: parser3, parser4: parser4, parser5: parser5)
}


func pair<A,B>(_ x: A) -> (B) -> (A,B) {
    return { y in (x,y) }
}

extension Date: Equatable {}
func ==(lhs: Date, rhs: Date) -> Bool {
    return lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
}

extension Character {
    
    func isMemberOfCharacterSet(_ set: CharacterSet) -> Bool {
        let normalized = String(self).precomposedStringWithCanonicalMapping
        let unicodes = normalized.unicodeScalars
        
        guard unicodes.count == 1 else { return false }
        return set.contains(UnicodeScalar(unicodes.first!.value))
    }
    
    var isNewlineOrSpace: Bool {
        return isMemberOfCharacterSet(.whitespacesAndNewlines)
    }
}

struct ImmutableCharacters: Stream {
    var characters: [Character]
    var start: Int
    
    init(string: String) {
        characters = Array(string.characters)
        start = 0
    }
    
    init(arrayLiteral elements: Character...) {
        characters = elements
        start = 0
    }
    
    mutating func popFirst() -> Character? {
        guard start < characters.count else { return nil }
        let oldStart = start
        start += 1
        return characters[oldStart]
    }
}
typealias FastParser = GenericParser<ImmutableCharacters, (), Character>

func parse(string: String) -> [Statement] {
    let parser = FastParser.newLine.many *> statements <* FastParser.space.many <* FastParser.eof
    let result = try! parser.run(sourceName: "", input: ImmutableCharacters(string: string))
    return result
}

let naturalString: GenericParser<ImmutableCharacters, (), String> = FastParser.digit.many1.map { digits in String(digits) }
let naturalWithCommaString = (FastParser.digit <|> FastParser.character(",")).many1.map( { digitsAndCommas in String(digitsAndCommas.filter { $0 != "," }) })

let natural: GenericParser<ImmutableCharacters, (), Int> = naturalString.map { Int($0)! }

func monthDay(_ separator: Character) -> GenericParser<ImmutableCharacters, (), (Int, Int?)> {
    let separatorInt = FastParser.character(separator) *> natural
    return lift2( { ($0, $1)} , separatorInt, separatorInt.optional)
}

func makeDate(one: Int, two: (Int,Int?)) -> Date {
    guard let day = two.1 else {
        return Date(year: nil, month: one, day: two.0)
    }
    return Date(year: one, month: two.0, day: day)
}

extension Date {
    static let parser:  GenericParser<ImmutableCharacters, (), Date> =
        lift2(makeDate, natural, monthDay("/") <|> monthDay("-"))
}

func lexeme<A>(_ parser: GenericParser<ImmutableCharacters,(), A>) -> GenericParser<ImmutableCharacters, (), A> {
    return parser <* spaceWithoutNewline.many
}

func lexline<A>(_ parser: GenericParser<ImmutableCharacters,(), A>) -> GenericParser<ImmutableCharacters, (), A> {
    return parser <* FastParser.oneOf(" \t").many <* FastParser.newLine
}

let noNewline: GenericParser<ImmutableCharacters,(),Character> = FastParser.newLine.noOccurence *> FastParser.anyCharacter
let spaceWithoutNewline: GenericParser<ImmutableCharacters,(),Character> = FastParser.character(" ") <|> FastParser.tab

let spacer = FastParser.tab <|> (spaceWithoutNewline *> spaceWithoutNewline)

let noteStart: FastParser = FastParser.character(";")
let trailingNoteStart = spacer *> noteStart
let noteBody = ({Note(String($0))} <^> noNewline.many)
let trailingNote = lexeme(trailingNoteStart) *> noteBody
let note = lexeme(noteStart) *> noteBody

let transactionCharacter = trailingNoteStart.noOccurence *> noNewline

let transactionState = FastParser.character("*").map { _ in TransactionState.cleared } <|> FastParser.character("!").map { _ in TransactionState.pending }

let transactionHelper: GenericParser<ImmutableCharacters, (), String> = transactionCharacter.many.map { String($0) }
let transactionTitle: GenericParser<ImmutableCharacters, (), (Date, TransactionState?, String)> =
    lift3( { ($0, $1, $2) }, lexeme(Date.parser), lexeme(transactionState.optional), transactionHelper)

let commodity: GenericParser<ImmutableCharacters, (), String> = string("USD") <|> string("EUR") <|> string("$")
let double: GenericParser<ImmutableCharacters, (), LedgerDouble> = lift3( { sign, x, fraction in // todo name x
    let sign = sign.map { String($0) } ?? ""
    guard let fraction = fraction else { return Double(sign + x)! }
    return Double("\(sign)\(x).\(fraction)")!
}, FastParser.character("-").optional, naturalWithCommaString, (FastParser.character(".") *> naturalString).optional)


let noSpace: GenericParser<ImmutableCharacters, (), Character> = FastParser.space.noOccurence *> FastParser.anyCharacter
let singleSpace: GenericParser<ImmutableCharacters, (), Character> = (FastParser.character(" ") <* FastParser.space.noOccurence).attempt

let amount: GenericParser<ImmutableCharacters, (), Amount> =
    lift2({ Amount(number: $1, commodity: $0) }, lexeme(commodity), double) <|>
    lift2(Amount.init, lexeme(double), commodity.optional)

let account = lift2({ String( $1.prepending($0) ) }, noSpace, (noSpace <|> singleSpace).many)

let balanceAssertion = lexeme(FastParser.character("=")) *> amount

// This is not very beautiful. Tries to parse either @@ or @ into a string
let costStart = lift2({ Cost.CostType(rawValue: $0 + ($1 ?? ""))! }, string("@"), string("@").optional)
let cost: GenericParser<ImmutableCharacters,(),Cost> = lift2(Cost.init, lexeme(costStart), amount)

let amountOrExpression = (AmountOrExpression.amount <^> amount <|> AmountOrExpression.expression <^> expression)

let posting: GenericParser<ImmutableCharacters, (), Posting> = lift5(Posting.init, lexeme(account), lexeme(amountOrExpression.optional), lexeme(cost.optional), lexeme(balanceAssertion.optional), (lexeme(noteStart) *> noteBody).optional)

let commentStart: GenericParser<ImmutableCharacters, (), Character> = FastParser.oneOf(";#%|*")

let comment: GenericParser<ImmutableCharacters, (), String> = commentStart *> spaceWithoutNewline.many *> ( { String($0) } <^> noNewline.many)

let postingOrNote = PostingOrNote.note <^> lexeme(note) <|> PostingOrNote.posting <^> lexeme(posting)

let transaction: GenericParser<ImmutableCharacters, (), Transaction> =
    lift3(Transaction.init, transactionTitle, lexeme(trailingNote.optional), ((FastParser.newLine *> spaceWithoutNewline.many1).attempt *> postingOrNote).many1)

func string(_ string: String) -> GenericParser<ImmutableCharacters, (), String> {
    return FastParser.string(ImmutableCharacters(string: string)) *> GenericParser(result: string)
}

let accountDirective: GenericParser<ImmutableCharacters, (), Statement> =
    lexeme(string("account")) *> (Statement.account <^> account)


indirect enum Expression: Equatable {
    case infix(`operator`: String, lhs: Expression, rhs: Expression)
    case amount(Amount)
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
    default: return false
    }
}

func binary(_ name: String, assoc: Associativity = .left) -> Operator<ImmutableCharacters, (), Expression> {
    let opParser = lexeme(string(name).attempt) >>- { name in // todo: is the attempt really necessary?
        return GenericParser(result: {
            Expression.infix(operator: name, lhs: $0, rhs: $1)
        })
    }
    return .infix(opParser, assoc)

}

func delimited(by character: Character) -> GenericParser<ImmutableCharacters,(),String> {
    let delimiter = FastParser.character(character)
    return delimiter *> ({ String($0) } <^> FastParser.anyCharacter.manyTill(delimiter))
}

let regex: GenericParser<ImmutableCharacters,(),String> = delimited(by: "/")

let string = delimited(by: "\"") <|> delimited(by: "'")

let ident = { String($0) } <^> (FastParser.alphaNumeric <|> FastParser.character("_")).many1

let opTable: OperatorTable<ImmutableCharacters, (), Expression> = [
    [ binary("*"), binary("/")],
    [ binary("+"), binary("-")],
    [ binary("=="), binary("!="), binary("<"), binary("<="), binary(">"), binary(">="), binary("=~"), binary("!~")],
    [ binary("&&")],
    [ binary("||")],

]

let openingParen: FastParser = lexeme(FastParser.character("("))
let closingParen: FastParser = lexeme(FastParser.character(")"))

let primitive: GenericParser<ImmutableCharacters,(),Expression> =
    Expression.amount <^> amount <|>
    Expression.regex <^> regex <|>
    Expression.string <^> string <|>
    Expression.ident <^> ident

struct AutomatedTransaction: Equatable {
    enum TransactionType: Equatable {
        case regex(String)
        case expr(Expression)
    }

    var type: TransactionType
    var postings: [Posting]
}

func ==(lhs: AutomatedTransaction.TransactionType, rhs: AutomatedTransaction.TransactionType) -> Bool {
    switch (lhs,rhs) {
    case let (.regex(l), .regex(r)): return l == r
    case let (.expr(l), .expr(r)): return l == r
    default: return false
    }
}

func ==(lhs: AutomatedTransaction, rhs: AutomatedTransaction) -> Bool {
    return lhs.type == rhs.type && lhs.postings == rhs.postings
}

let definition = lift2(Statement.definition, lexeme(string("define")) *> lexeme(ident), lexeme(FastParser.character("=")) *> expression)

let tag = Statement.tag <^> (lexeme(string("tag")) *> lexeme(ident))

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

let commodityDirective = lexeme(string("commodity")) *> (Statement.commodity <^> commodity)
let yearDirective = lexeme(string("year")) *> (Statement.year <^> natural)

let statement: GenericParser<ImmutableCharacters,(),Statement> = (Statement.transaction <^> transaction) <|> yearDirective <|> commodityDirective <|> (Statement.comment <^> comment) <|> accountDirective <|> definition <|> tag <|> (Statement.automated <^> automatedTransaction)

let newlineAndSpacedNewlines = FastParser.newLine *> FastParser.space.many
let statements = (statement <* newlineAndSpacedNewlines).many


let expression = opTable.makeExpressionParser { expression in
    expression.between(openingParen, closingParen) <|>
        lexeme(primitive) <?> "simple expression"

    } <?> "expression"

let postings = ((FastParser.newLine *> spaceWithoutNewline.many1).attempt *> posting).many1
let automatedExpression = AutomatedTransaction.TransactionType.expr <^> (lexeme(string("expr")) *> (lexeme(FastParser.character("'")) *> lexeme(expression) <* FastParser.character("'"))) <|>
  AutomatedTransaction.TransactionType.regex <^> regex
let automatedTransaction: GenericParser<ImmutableCharacters,(),AutomatedTransaction> = lift2(AutomatedTransaction.init, lexeme(FastParser.character("=")) *> lexeme(automatedExpression), postings)
