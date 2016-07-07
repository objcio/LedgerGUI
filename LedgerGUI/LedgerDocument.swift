//
//  LedgerDocument.swift
//  LedgerGUI
//
//  Created by Florian on 06/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

final class DocumentState {
    var state: State = State() {
        didSet { update() }
    }
    var accountFilter: String? {
        didSet {
            // TODO
            let filteredTransactions: [EvaluatedTransaction]
            if let filter = accountFilter {
                filteredTransactions = state.evaluatedTransactions.filter { transaction in
                    transaction.postings.filter { $0.account.hasPrefix(filter) }.count > 0
                }
            } else {
                filteredTransactions = state.evaluatedTransactions
            }
            self.windowController?.registerViewController?.transactions = filteredTransactions
        }
    }
    
    var windowController: LedgerWindowController? {
        didSet {
            windowController?.balanceViewController?.didSelect { account in
                self.accountFilter = account
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


