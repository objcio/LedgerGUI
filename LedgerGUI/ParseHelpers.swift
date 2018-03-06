//
//  ParseHelpers.swift
//  LedgerGUI
//
//  Created by Florian on 30/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation


struct ImmutableCharacters: Stream {
    var substring: Substring
    var start: String.Index
    
    init(string: String) {
        substring = Substring(string)
        start = substring.startIndex
    }
    
    init(arrayLiteral elements: Character...) {
        substring = Substring(elements)
        start = substring.startIndex
    }
    
    mutating func popFirst() -> Character? {
        guard start < substring.endIndex else { return nil }
        let oldStart = start
        start = substring.index(start, offsetBy: 1)
        return substring[oldStart]
    }
    
    var first: Character? {
        guard start < substring.endIndex else { return nil }
        return substring[start]
    }
    
    var isEmpty: Bool {
        return start < substring.endIndex
    }
}

typealias FastParser = GenericParser<ImmutableCharacters, (), Character>



func string(_ string: String) -> GenericParser<ImmutableCharacters, (), String> {
    return FastParser.string(string) *> GenericParser(result: string)
}

func surrounded(by character: Character) -> GenericParser<ImmutableCharacters,(),String> {
    let delimiter = FastParser.character(character)
    return delimiter *> ({ String($0) } <^> FastParser.anyCharacter.manyTill(delimiter))
}

func lift2<Param1, Param2, Result, StreamType, UserState>(_ function: @escaping (Param1, Param2) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift2(function, parser1: parser1, parser2: parser2)
}

func lift3<Param1, Param2, Param3, Result, StreamType, UserState>(_ function: @escaping (Param1, Param2, Param3) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>, _ parser3: GenericParser<StreamType, UserState, Param3>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift3(function, parser1: parser1, parser2: parser2, parser3: parser3)
}

func lift4<Param1, Param2, Param3, Param4, Result, StreamType, UserState>(_ function: @escaping (Param1, Param2, Param3, Param4) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>, _ parser3: GenericParser<StreamType, UserState, Param3>, _ parser4: GenericParser<StreamType, UserState, Param4>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift4(function, parser1: parser1, parser2: parser2, parser3: parser3, parser4: parser4)
}


func lift5<Param1, Param2, Param3, Param4, Param5, Result, StreamType, UserState>(_ function: @escaping (Param1, Param2, Param3, Param4, Param5) -> Result, _ parser1: GenericParser<StreamType, UserState, Param1>, _ parser2: GenericParser<StreamType, UserState, Param2>, _ parser3: GenericParser<StreamType, UserState, Param3>, _ parser4: GenericParser<StreamType, UserState, Param4>, _ parser5: GenericParser<StreamType, UserState, Param5>) -> GenericParser<StreamType, UserState, Result> {
    return GenericParser.lift5(function, parser1: parser1, parser2: parser2, parser3: parser3, parser4: parser4, parser5: parser5)
}






