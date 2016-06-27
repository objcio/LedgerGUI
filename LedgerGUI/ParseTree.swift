//
//  ParseTree.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 27/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

struct Date {
    let year: Int
    let month: Int
    let day: Int
}

enum TransactionState: Character {
    case cleared = "*"
    case pending = "!"
}

extension TransactionState: Equatable { }

typealias LedgerDouble = Double // TODO use infinite precision arithmetic

enum PostingOrNote {
    case posting(Posting)
    case note(Note)
}
