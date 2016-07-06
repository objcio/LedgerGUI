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
            delegate.transactions = transactions
            tableView?.reloadData()
        }
    }
    
    let delegate = RegisterDelegate()
    var tableView: NSTableView?
    
    override func viewDidLoad() {
        let tableView = NSTableView()
        let column = NSTableColumn(identifier: "first")
        tableView.addTableColumn(column)
        tableView.dataSource = delegate
        tableView.delegate = delegate
        let nib = NSNib(nibNamed: "RegisterCell", bundle: nil)
        tableView.register(nib, forIdentifier: "Cell")
        
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

class RegisterDelegate: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    var transactions: [EvaluatedTransaction] = []
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.make(withIdentifier: "Cell", owner: self)! as! RegisterCell
        let transaction = transactions[row]
        cell.title = transaction.title
        
        cell.setPostings(postings: transaction.postings)
        let calendar = Calendar.current()
        cell.set(date: calendar.date(from: transaction.date.components)!)
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let postings = transactions[row].postings
        return 54 + CGFloat(postings.count) * (17+8)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return transactions.count
    }
}

class PostingView: NSView {
    @IBOutlet weak var account: NSTextField!
    @IBOutlet weak var amount: NSTextField!
}

class RegisterCell: NSView {
    static let postingNib = NSNib(nibNamed: "Posting", bundle: nil)!
    
    @IBOutlet weak var stackView: NSStackView!
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
        formatter.dateStyle = .shortStyle
        formatter.timeStyle = .noStyle
        dateLabel.stringValue = formatter.string(from: date)
    }
    
    func setPostings(postings: [EvaluatedPosting]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for posting in postings {
            var objects: NSArray = NSArray()
            guard RegisterCell.postingNib.instantiate(withOwner: nil, topLevelObjects: &objects) else {
                fatalError("Couldn't instantiate")
            }
            let postingView = objects.flatMap { $0 as? PostingView }.first!
            let font = NSFont.systemFont(ofSize: NSFont.systemFontSize())
            let accountFont = posting.virtual ? font.italic : font
            let attributes = [NSFontAttributeName: accountFont]
            postingView.account.attributedStringValue = AttributedString(string: posting.account, attributes: attributes)
            postingView.amount.attributedStringValue = AttributedString(string: posting.amount.displayValue, attributes: attributes)
            postingView.amount.textColor = posting.amount.color
            stackView.addArrangedSubview(postingView)
        }
    }
}

