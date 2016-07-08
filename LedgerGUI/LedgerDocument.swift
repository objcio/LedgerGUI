//
//  LedgerDocument.swift
//  LedgerGUI
//
//  Created by Florian on 06/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

enum Filter {
    case account(String)
    case string(String)
    case period(from: Foundation.Date, to: Foundation.Date)
}

extension EvaluatedTransaction {
    func matches(_ search: Filter) -> Bool {
        switch search {
        case .account:
            return postings.first { $0.matches(search) } != nil
        case .string(let string):
            return title.lowercased().contains(string.lowercased()) || postings.first { $0.matches(search) } != nil
        case .period(let from, let to):
            return date.date >= from && date.date <= to
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
        case .period:
            return false
        }
    }
}

struct DocumentState {
    var ledger: Ledger = Ledger()
    var filter: Filter?

    var filteredTransactions: [EvaluatedTransaction] {
        guard let filter = filter else { return ledger.evaluatedTransactions }
        return ledger.evaluatedTransactions.filter { $0.matches(filter) }
    }
}

final class DocumentController {
    var documentState = DocumentState() {
        didSet {
            update()
        }
    }
    
    var windowController: LedgerWindowController? {
        didSet {
            windowController?.balanceViewController?.didSelect { account in
                self.documentState.filter = account.map { .account($0) }
            }
            windowController?.didSearch = { search in
                self.documentState.filter = search.isEmpty ? nil : .string(search)
            }
            update()
        }
    }

    func update() {
        DispatchQueue.main.async {
            self.windowController?.balanceViewController?.ledger = self.ledger
            self.windowController?.registerViewController?.transactions = self.documentState.filteredTransactions
            self.windowController?.registerViewController?.filter = self.documentState.filter
        }
    }
    
    var ledger: Ledger {
        get { return documentState.ledger }
        set { documentState.ledger = newValue }
    }
}

final class LedgerDocument: NSDocument {
    var controller = DocumentController()
    
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return true
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        guard let contents = String(data: data, encoding: .utf8) else { throw "Couldn't read data" }
        var ledger = Ledger()
        let statements = parse(string: contents)
        for statement in statements {
            try! ledger.apply(statement)
        }
        controller.ledger = ledger
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Storyboard", bundle: nil)
        let wc = storyboard.instantiateController(withIdentifier: "WindowController") as! LedgerWindowController
        wc.document = self
        addWindowController(wc)
        wc.showWindow(nil)
        controller.windowController = wc
    }
}


