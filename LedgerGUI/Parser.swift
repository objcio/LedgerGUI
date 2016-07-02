//
//  Parser.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 23/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation


func parse(string: String) -> [Statement] {
    let parser = FastParser.newLine.many *> statements <* FastParser.space.many <* FastParser.eof
    do {
        let result: [Statement] = try parser.run(sourceName: "", input: ImmutableCharacters(string: string))
        return result
    } catch {
        print(error)
        fatalError()
    }
}


let naturalString: GenericParser<ImmutableCharacters, (), String> = FastParser.digit.many1.map { digits in String(digits) }
let naturalWithCommaString = (FastParser.digit <|> FastParser.character(",")).many1.map( { digitsAndCommas in String(digitsAndCommas.filter { $0 != "," }) })
let natural: GenericParser<ImmutableCharacters, (), Int> = naturalString.map { Int($0)! }
let unsignedDouble: GenericParser<ImmutableCharacters, (), LedgerDouble> = lift2( { integerPart, fractionalPart in
    guard let fraction = fractionalPart else { return Double(integerPart)! }
    return Double("\(integerPart).\(fraction)")!
    }, naturalWithCommaString, (FastParser.character(".") *> naturalString).optional)
let double: GenericParser<ImmutableCharacters, (), LedgerDouble> = lift2( { sign, double in
    return sign == "-" ? -double : double
    }, FastParser.character("-").optional, unsignedDouble)

let noNewline: GenericParser<ImmutableCharacters,(),Character> = FastParser.anyCharacter.onlyIf(peek: { $0 != "\n" })
let spaceWithoutNewline: GenericParser<ImmutableCharacters,(),Character> = FastParser.character(" ") <|> FastParser.tab
let noSpace: GenericParser<ImmutableCharacters, (), Character> = FastParser.anyCharacter.onlyIf(peek: { !$0.isSpace })
let singleSpace: GenericParser<ImmutableCharacters, (), Character> = (FastParser.character(" ") <* FastParser.space.noOccurence).attempt
let newlineAndSpacedNewlines = FastParser.newLine *> FastParser.space.many

func lexeme<A>(_ parser: GenericParser<ImmutableCharacters,(), A>) -> GenericParser<ImmutableCharacters, (), A> {
    return parser <* spaceWithoutNewline.many
}



let commentStart: GenericParser<ImmutableCharacters, (), Character> = FastParser.oneOf(";#%|*")
let comment: GenericParser<ImmutableCharacters, (), String> =
    commentStart *> spaceWithoutNewline.many *> ( { String($0) } <^> noNewline.many)


let accountDirective: GenericParser<ImmutableCharacters, (), Statement> =
    lexeme(string("account")) *> (Statement.account <^> account)
let definitionDirective = lift2(
    Statement.definition,
    lexeme(string("define")) *> lexeme(ident),
    lexeme(FastParser.character("=")) *> expression
)
let tagDirective = Statement.tag <^> (lexeme(string("tag")) *> lexeme(ident))
let commodityDirective = lexeme(string("commodity")) *> (Statement.commodity <^> commodity)
let yearDirective = lexeme(string("year")) *> (Statement.year <^> natural)



let noteStart: FastParser = FastParser.character(";")
let noteBody = ({Note(String($0))} <^> noNewline.many)
let note = lexeme(noteStart) *> noteBody

let trailingNoteSpacer = FastParser.tab <|> (spaceWithoutNewline *> spaceWithoutNewline)
let trailingNoteStart = trailingNoteSpacer *> noteStart
let trailingNote = lexeme(trailingNoteStart) *> noteBody



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

let date: GenericParser<ImmutableCharacters, (), Date> = lift2(makeDate, natural, monthDay("/") <|> monthDay("-"))

let transactionDescriptionCharacter = trailingNoteStart.noOccurence *> noNewline
let transactionDescription: GenericParser<ImmutableCharacters, (), String> = { String($0) } <^> transactionDescriptionCharacter.many
let transactionState =
    FastParser.character("*").map { _ in TransactionState.cleared } <|>
    FastParser.character("!").map { _ in TransactionState.pending }
let transactionTitle: GenericParser<ImmutableCharacters, (), (Date, TransactionState?, String)> =
    lift3({ ($0, $1, $2) }, lexeme(date), lexeme(transactionState.optional), transactionDescription)



let account = lift2({ String( $1.prepending($0) ) }, noSpace, (noSpace <|> singleSpace).many)

let amount: GenericParser<ImmutableCharacters, (), Amount> =
    lift2({ Amount($1, commodity: Commodity($0)) }, lexeme(commodity), double) <|>
    lift2(Amount.init, lexeme(double), Commodity.init <^> commodity.optional)
let unsignedAmount: GenericParser<ImmutableCharacters, (), Amount> =
    lift2({ Amount($1, commodity: Commodity($0)) }, lexeme(commodity), unsignedDouble) <|>
        lift2(Amount.init, lexeme(unsignedDouble), Commodity.init <^> commodity.optional)

let commodity: GenericParser<ImmutableCharacters, (), String> = (string("USD") <|> string("EUR") <|> string("$")) <?> "commodity"

let balanceAssertion = lexeme(FastParser.character("=")) *> amount
let costStart = lift2({ Cost.CostType(rawValue: $0 + ($1 ?? ""))! }, string("@"), string("@").optional)
let cost: GenericParser<ImmutableCharacters,(),Cost> = lift2(Cost.init, lexeme(costStart), unsignedAmount)

let amountOrExpression = (Expression.amount <^> amount <|> (openingParen *> expression <* closingParen))

let posting: GenericParser<ImmutableCharacters, (), Posting> = lift5(
    Posting.init,
    lexeme(account),
    lexeme(amountOrExpression.optional),
    lexeme(cost.optional),
    lexeme(balanceAssertion.optional),
    (lexeme(noteStart) *> noteBody).optional
)

let postingOrNote = PostingOrNote.note <^> lexeme(note) <|> PostingOrNote.posting <^> lexeme(posting)

let transaction: GenericParser<ImmutableCharacters, (), Transaction> = lift3(
    Transaction.init,
    transactionTitle,
    lexeme(trailingNote.optional) <* FastParser.newLine,
    (spaceWithoutNewline.many1 *> postingOrNote <* FastParser.newLine).many1
)


let automatedPosting: GenericParser<ImmutableCharacters, (), AutomatedPosting> = lift2(AutomatedPosting.init, lexeme(account), lexeme(amountOrExpression))
let automatedPostings = ((FastParser.newLine *> spaceWithoutNewline.many1).attempt *> automatedPosting).many1
let automatedExpression = (lexeme(string("expr")) *> (lexeme(FastParser.character("'")) *> lexeme(expression) <* FastParser.character("'"))) <|>
    { Expression.infix(operator: "=~", lhs: .ident("account"), rhs: .regex($0)) } <^> regex
let automatedTransaction: GenericParser<ImmutableCharacters,(),AutomatedTransaction> = lift2(AutomatedTransaction.init, lexeme(FastParser.character("=")) *> lexeme(automatedExpression), automatedPostings)


let openingParen: FastParser = lexeme(FastParser.character("("))
let closingParen: FastParser = lexeme(FastParser.character(")"))
let regex: GenericParser<ImmutableCharacters,(),String> = surrounded(by: "/")
let stringLiteral = surrounded(by: "\"") <|> surrounded(by: "'")
let identCharacter = FastParser.alphaNumeric <|> FastParser.character("_")
let ident = { String($0) } <^> identCharacter.many1
let bool = (({ _ in true } <^> string("true") <|> { _ in false } <^> string("false")) <* identCharacter.noOccurence).attempt

let primitive: GenericParser<ImmutableCharacters,(),Expression> =
    Expression.amount <^> amount <|>
        Expression.regex <^> regex <|>
        Expression.string <^> stringLiteral <|>
        Expression.bool <^> bool <|>
        Expression.ident <^> ident

func binary(_ name: String, assoc: Associativity = .left) -> Operator<ImmutableCharacters, (), Expression> {
    let opParser = lexeme(string(name).attempt) >>- { name in
        return GenericParser(result: {
            Expression.infix(operator: name, lhs: $0, rhs: $1)
        })
    }
    return .infix(opParser, assoc)
}

let opTable: OperatorTable<ImmutableCharacters, (), Expression> = [
    [binary("*"), binary("/")],
    [binary("+"), binary("-")],
    [binary("=="), binary("!="), binary("<"), binary("<="), binary(">"), binary(">="), binary("=~"), binary("!~")],
    [binary("&&")],
    [binary("||")],
]

let expression = opTable.makeExpressionParser { expression in
    expression.between(openingParen, closingParen) <|> lexeme(primitive) <?> "primitive expression"
} <?> "expression"

func lexline<A>(_ p: GenericParser<ImmutableCharacters, (), A>) -> GenericParser<ImmutableCharacters, (), A> {
    return p <* FastParser.space.many
}


let statement: GenericParser<ImmutableCharacters,(),Statement> =
    (Statement.transaction <^> transaction) <|>
    yearDirective <|>
    commodityDirective <|>
    (Statement.comment <^> comment) <|>
    accountDirective <|>
    definitionDirective <|>
    tagDirective <|>
    (Statement.automated <^> automatedTransaction)

let statements = lexline(statement).many

