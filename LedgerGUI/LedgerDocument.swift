//
//  LedgerDocument.swift
//  LedgerGUI
//
//  Created by Florian on 06/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

enum Filter {
    case account(name: String)
    case string(String)
}

extension EvaluatedTransaction {
    func matches(_ search: Filter) -> Bool {
        switch search {
        case .account:
            return postings.first { $0.matches(search) } != nil
        case .string:
            return postings.first { $0.matches(search) } != nil
        }
    }
}

extension EvaluatedPosting {
    func matches(_ search: Filter) -> Bool {
        switch search {
        case .account(let name):
            return account.hasPrefix(name)
        case .string(let string):
            return account.lowercased().contains(string.lowercased()) || amount.displayValue.contains(string)

        }
    }
}

// Pull this out into two parts
final class DocumentState {
    var state: State = State() {
        didSet { update() }
    }
    var filter: Filter? {
        didSet {
            let filteredTransactions: [EvaluatedTransaction]
            if let filter = filter {
                filteredTransactions = state.evaluatedTransactions.filter { $0.matches(filter) }
            } else {
                filteredTransactions = state.evaluatedTransactions
            }
            self.windowController?.registerViewController?.transactions = filteredTransactions
            self.windowController?.registerViewController?.filter = filter
        }
    }
    
    var windowController: LedgerWindowController? {
        didSet {
            windowController?.balanceViewController?.didSelect { account in
                self.filter = account.map { .account(name: $0) }
            }
            windowController?.didSearch = { search in
                self.filter = search.isEmpty ? nil : .string(search)
            }
            update()
        }
    }

    func update() {
        DispatchQueue.main.async {
            self.windowController?.balanceViewController?.state = self.state
            self.windowController?.registerViewController?.transactions = self.state.evaluatedTransactions
        }
    }
}

final class LedgerDocument: NSDocument {
    var documentState: DocumentState = DocumentState()
    
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return true
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        guard let contents = String(data: data, encoding: .utf8) else { throw "Couldn't read data" }
        var state = State()
        let statements = parse(string: contents)
        for statement in statements {
            try! state.apply(statement)
        }
        documentState.state = state
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Storyboard", bundle: nil)
        let wc = storyboard.instantiateController(withIdentifier: "WindowController") as! LedgerWindowController
        wc.document = self
        addWindowController(wc)
        wc.showWindow(nil)
        documentState.windowController = wc
    }
}


