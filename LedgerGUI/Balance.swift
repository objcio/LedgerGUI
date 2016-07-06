//
//  Balance.swift
//  LedgerGUI
//
//  Created by Florian on 06/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

class BalanceViewController: NSViewController {
    lazy var dataSourceAndDelegate: OutlineDataSourceAndDelegate<BalanceTreeItem, BalanceCell> = OutlineDataSourceAndDelegate(configure: self.configureCell)
    
    func didSelect(_ didSelect: (account: String?) -> ()) {
        dataSourceAndDelegate.didSelect = { balanceTreeItem in
            didSelect(account: balanceTreeItem?.accountName)
        }
    }
    
    @IBOutlet weak var outlineView: NSOutlineView? {
        didSet {
            dataSourceAndDelegate.configure = self.configureCell
            outlineView?.dataSource = dataSourceAndDelegate
            outlineView?.delegate = dataSourceAndDelegate
        }
    }
    
    func configureCell(item: BalanceTreeItem, cell: BalanceCell) {
        cell.titleLabel.stringValue = item.title
        let (key, value) = item.amount.first!
        if item.amount.count > 1 {
            Swift.print("Cannot display multiple amounts yet...")
        }
        
        let amount = Amount(value, commodity: key)
        cell.amount.stringValue = amount.displayValue
        cell.amount.textColor = amount.color
    }
    
    var state: State? {
        didSet {
            let balance = state?.balance ?? [:]
            dataSourceAndDelegate.tree = balanceTree(items: balance)
            outlineView?.reloadData() // TODO use a diff?
            outlineView?.expandItem(nil, expandChildren: true)
        }
    }
}

class OutlineDataSourceAndDelegate<A: Tree, Cell: NSTableCellView>: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource {
    var tree: [A] = []
    var configure: (A, Cell) -> () = { _ in }
    var didSelect: (A?) -> () = { _ in }
    
    init(configure: (A, Cell) -> ()) {
        self.configure = configure
    }
    
    let cellIdentifier = "Cell"
    
    
    func children(item: AnyObject?) -> [A] {
        guard let item = item else { return tree }
        return (item as! A).children
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        return children(item: item).count
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return children(item: item).count > 0
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let outlineView = notification.object as! NSOutlineView
        didSelect(outlineView.item(atRow: outlineView.selectedRow) as? A)
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        return children(item: item)[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        let item = item as! A
        let cell = outlineView.make(withIdentifier: cellIdentifier, owner: self)! as! Cell
        configure(item, cell)
        return cell
    }

}

func balanceTree(items: State.Balance) -> [BalanceTreeItem] {
    let sortedAccounts = Array(items).sorted { p1, p2 in
        return p1.key < p2.key
    }
    
    let rootItem = BalanceTreeItem(title:"", accountName: "", amount: [:])
    
    for account in sortedAccounts {
        let components = account.key.components(separatedBy: ":")
        rootItem.insert(child: components, accountName: account.key, amount: account.value)
    }
    
    print(rootItem.children)
    
    return rootItem.children
    
}

final class BalanceTreeItem: Tree {
    var title: String
    var accountName: String
    var amount: [Commodity:LedgerDouble]
    var children: [BalanceTreeItem]
    init(title: String, accountName: String, amount: [Commodity:LedgerDouble]) {
        self.title = title
        self.accountName = accountName
        self.amount = amount
        self.children = []
    }
    
}

extension BalanceTreeItem {
    func insert(child name: [String], accountName: String, amount: [Commodity:LedgerDouble]) {
        // TODO clean this up
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
                child.insert(child: restName, accountName: accountName, amount: amount)
                return
            }
        }
        
        let newChild = BalanceTreeItem(title: namePrefix, accountName: accountName, amount: amount)
        newChild.insert(child: restName, accountName: accountName, amount: amount)
        children.append(newChild)
    }
}

class BalanceCell: NSTableCellView {
    @IBOutlet weak var amount: NSTextField!
    @IBOutlet weak var titleLabel: NSTextField!
    
}

protocol Tree: class {
    var children: [Self] { get }
}
