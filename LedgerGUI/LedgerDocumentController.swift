//
//  LedgerDocumentController.swift
//  LedgerGUI
//
//  Created by Florian Kugler on 01/09/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

enum Filter {
    case account(String)
    case string(String)
    case period(from: EvaluatedDate, to: EvaluatedDate)
}

extension EvaluatedTransaction {
    func matches(_ search: [Filter]) -> Bool {
        return search.all(matches)
    }
    
    func matches(_ search: Filter) -> Bool {
        switch search {
        case .account:
            return postings.first { $0.matches(search) } != nil
        case .string(let string):
            return title.lowercased().contains(string.lowercased()) || postings.first { $0.matches(search) } != nil
        case .period(let from, let to):
            return date >= from && date <= to
        }
    }
}

extension EvaluatedPosting {
    func matches(_ search: [Filter]) -> Bool {
        return search.all(matches)
    }
    
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
    var filters: [Filter] = []
    
    var filteredTransactions: [EvaluatedTransaction] {
        guard !filters.isEmpty else { return ledger.evaluatedTransactions }
        return ledger.evaluatedTransactions.filter { $0.matches(filters) }
    }
}

final class LedgerDocumentController {
    var documentState = DocumentState() {
        didSet {
            update()
        }
    }
    
    var windowController: LedgerWindowController? {
        didSet {
            windowController?.balanceViewController?.didSelect { account in
                self.documentState.filters = account.map { [.account($0)] } ?? []
            }
            windowController?.didSearch = { search in
                self.documentState.filters = Filter.parse(search)
            }
            update()
        }
    }
    
    func update() {
        DispatchQueue.main.async {
            self.windowController?.balanceViewController?.ledger = self.ledger
            self.windowController?.registerViewController?.transactions = self.documentState.filteredTransactions
            self.windowController?.registerViewController?.filters = self.documentState.filters
        }
    }
    
    var ledger: Ledger {
        get { return documentState.ledger }
        set { documentState.ledger = newValue }
    }
}

