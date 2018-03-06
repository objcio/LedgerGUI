//
//  RegisterViewController.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 04/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

class RegisterViewController: NSViewController {
    var transactions: [EvaluatedTransaction] = [] {
        didSet {
            delegate.transactions = transactions.reversed()
            tableView?.reloadData()
        }
    }
    
    var filters: [Filter] = [] {
        didSet {
            delegate.filters = filters
            tableView?.reloadData()
        }
    }

    let delegate = RegisterDelegate()
    var tableView: NSTableView?
    
    override func viewDidLoad() {
        let tableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "first"))
        tableView.addTableColumn(column)
        tableView.dataSource = delegate
        tableView.delegate = delegate
        tableView.headerView = nil
        let nib = NSNib(nibNamed: NSNib.Name(rawValue: "TransactionCell"), bundle: nil)
        tableView.register(nib, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TransactionCell"))
        let postingNib = NSNib(nibNamed: NSNib.Name(rawValue: "PostingCell"), bundle: nil)
        tableView.register(postingNib, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PostingCell"))
        
        let scrollView = NSScrollView()
        let clipView = NSClipView()
        
        clipView.documentView = tableView
        scrollView.contentView = clipView
        
        view.addSubview(scrollView)
        scrollView.constrainEdges(toMarginOf: view)
        scrollView.hasVerticalScroller = true
        
        self.tableView = tableView
        
        view.widthAnchor.constraint(greaterThanOrEqualToConstant: 500).isActive = true
    }
    
}

enum RegisterRow {
    case title(EvaluatedTransaction)
    case posting(EvaluatedPosting)
}

class RegisterDelegate: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    var rows: [RegisterRow] = []
    var transactions: [EvaluatedTransaction] = [] {
        didSet {
            rows = transactions.flatMap { transaction in
                [.title(transaction)] + transaction.postings.map { .posting($0) }
            }
        }
    }
    
    var filters: [Filter] = []
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case .title(let transaction):
            return transactionCell(tableView, transaction)
        case .posting(let posting):
            return postingCell(tableView, posting)
        }
    }
    
    func transactionCell(_ tableView: NSTableView, _ transaction: EvaluatedTransaction) -> NSView {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TransactionCell"), owner: self)! as! TransactionCell
        cell.title = transaction.title
        cell.set(date: transaction.date.date)
        return cell
    }
    
    func postingCell(_ tableView: NSTableView, _ posting: EvaluatedPosting) -> NSView {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PostingCell"), owner: self)! as! PostingCell
        let highlighted = filters.some(posting.matches)

        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let accountFont = posting.virtual ? font.italic : font
        var attributes: [NSAttributedStringKey: AnyObject] = [.font: accountFont]
        if highlighted {
            attributes[.backgroundColor] = NSColor.yellow
        }
        
        cell.account.attributedStringValue = NSAttributedString(string: posting.account, attributes: attributes)
        cell.amount.attributedStringValue = NSAttributedString(string: posting.amount.displayValue, attributes: attributes)
        cell.amount.textColor = posting.amount.color
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch rows[row] {
        case .posting: return 20
        case .title: return 34
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }
}

class PostingCell: NSView {
    @IBOutlet weak var account: NSTextField!
    @IBOutlet weak var amount: NSTextField!
}

class TransactionCell: NSView {
    @IBOutlet weak var dateLabel: NSTextField!
    @IBOutlet private weak var titleLabel: NSTextField!
    
    var title: String {
        get {
            return titleLabel.stringValue
        }
        set {
            titleLabel.stringValue = newValue
        }
    }

    func set(date: Foundation.Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        dateLabel.stringValue = formatter.string(from: date)
    }
}
