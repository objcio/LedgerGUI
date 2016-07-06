//
//  RegisterViewController.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 04/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

extension NSView {
    func constrainEdges(toMarginOf otherView: NSView) {
        translatesAutoresizingMaskIntoConstraints = false

        topAnchor.constraint(equalTo: otherView.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: otherView.bottomAnchor).isActive = true
        leftAnchor.constraint(equalTo: otherView.leftAnchor).isActive = true
        rightAnchor.constraint(equalTo: otherView.rightAnchor).isActive = true
    }
}

class LedgerWindowController: NSWindowController {
    var state: State? {
        didSet {
            reload()
        }
    }

    func reload() {
        let balanceVC = self.contentViewController?.childViewControllers.flatMap( { $0 as? BalanceViewController }).first
        let registerVC = self.contentViewController?.childViewControllers.flatMap( { $0 as? RegisterViewController}).first
        balanceVC?.state = state
        registerVC?.state = state
    }
}


class LedgerDocument: NSDocument {
    var windowController: LedgerWindowController? {
        didSet {
            updateWindowController()
        }
    }
    
    var state: State? {
        didSet {
            updateWindowController()
        }
    }
    
    func updateWindowController() {
        DispatchQueue.main.async {
            self.windowController?.state = self.state
        }
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        guard let contents = String(data: data, encoding: .utf8) else { throw "Couldn't read data" }
        var newState = State()
        let statements = parse(string: contents)
        for statement in statements {
            try! newState.apply(statement)
        }
        self.state = newState
    }
    
    override func presentedItemDidChange() {
        Swift.print("x")
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Storyboard", bundle: nil)
        let wc = storyboard.instantiateController(withIdentifier: "WindowController") as! LedgerWindowController
        wc.document = self
        addWindowController(wc)
        windowController = wc
        wc.showWindow(nil)
    }
}


class RegisterViewController: NSViewController {
    var state: State? {
        didSet {
            delegate.transactions = state?.evaluatedTransactions ?? []
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

extension NSFont {
    var italic: NSFont {
        return NSFontManager.shared().convert(self, toHaveTrait: .italicFontMask)
    }
}

extension Amount {
    var displayValue: String {
        let formatter = NumberFormatter()
        formatter.currencySymbol = commodity.value
        formatter.numberStyle = .currencyAccounting
        return formatter.string(from: number.value) ?? ""
    }
    
    var color: NSColor {
        return isNegative ? .red() : .black()
    }
}

class BalanceViewController: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView! {
        didSet {
            outlineView.dataSource = delegate
            outlineView.delegate = delegate
        }
    }
    var state: State? {
        didSet {
            let balance = state?.balance ?? [:]
            delegate.balanceTree = balanceTree(items: balance)
            outlineView.reloadData()
            outlineView.expandItem(nil, expandChildren: true)
        }
    }

    var delegate = BalanceDelegate()
}

func balanceTree(items: State.Balance) -> [BalanceTreeItem] {
    let sortedAccounts = Array(items).sorted { p1, p2 in
        return p1.key < p2.key
    }

    let rootItem = BalanceTreeItem(title:"", amount: [:])

    for account in sortedAccounts {
        let components = account.key.components(separatedBy: ":")
        rootItem.insert(child: components, amount: account.value)
    }

    print(rootItem.children)

    return rootItem.children

}

class BalanceTreeItem {
    var title: String
    var amount: [Commodity:LedgerDouble]
    var children: [BalanceTreeItem]
    init(title: String, amount: [Commodity:LedgerDouble]) {
        self.title = title
        self.amount = amount
        self.children = []
    }

}

extension BalanceTreeItem {
    func insert(child name: [String], amount: [Commodity:LedgerDouble]) {
        guard name.count > 0 else { return }

        var restName = name
        let namePrefix = restName.remove(at: 0)
        for (commodity, value) in amount {
            if value != 0 {
                self.amount[commodity, or: 0] += value
            }
        }

        for child in children {
            if child.title == namePrefix {
                child.insert(child: restName, amount: amount)
                return
            }
        }

        let newChild = BalanceTreeItem(title: namePrefix, amount: amount)
        newChild.insert(child: restName, amount: amount)
        children.append(newChild)
    }
}

class BalanceCell: NSTableCellView {
    @IBOutlet weak var amount: NSTextField!
    @IBOutlet weak var titleLabel: NSTextField!

}

class BalanceDelegate: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var balanceTree: [BalanceTreeItem] = []

    func children(item: AnyObject?) -> [BalanceTreeItem] {
        guard let item = item else { return balanceTree }
        return (item as! BalanceTreeItem).children
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        return children(item: item).count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return children(item: item).count > 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        return children(item: item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        let item = item as! BalanceTreeItem

        let cell = outlineView.make(withIdentifier: "Cell", owner: self)! as! BalanceCell
        cell.titleLabel.stringValue = item.title
        let (key, value) = item.amount.first!
        if item.amount.count > 1 {
            Swift.print("Cannot display multiple amounts yet...")
        }

        let amount = Amount(value, commodity: key)
        cell.amount.stringValue = amount.displayValue
        cell.amount.textColor = amount.color
        return cell
    }
}
