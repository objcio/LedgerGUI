//
//  BalanceTree.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 07-07-16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

func balanceTree(items: State.Balance) -> [BalanceTreeNode] {
    let sortedAccounts = Array(items).sorted { p1, p2 in
        return p1.key < p2.key
    }
    
    var rootItem = BalanceTreeNode(accountName: nil, amount: [:])
    
    for account in sortedAccounts {
        let node = BalanceTreeNode(accountName: account.key, amount: account.value)
        rootItem.insert(node: node)
    }
    
    return rootItem.children
}


struct BalanceTreeNode: Tree {
    var amount: [Commodity:LedgerDouble]
    var children: [BalanceTreeNode] = []
    var path: [String]
    
    var title: String {
        return path.last ?? ""
    }

    var accountName: String {
        return path.joined(separator: ":")
    }

    init(accountName: String?, amount: [Commodity:LedgerDouble]) {
        path = accountName?.components(separatedBy: ":") ?? []
        self.amount = amount
    }
    
    init(path: [String], amount: [Commodity: LedgerDouble] = [:]) {
        self.path = path
        self.amount = amount
    }
}

extension Array {
    mutating func index(where f: (Element) -> Bool, orAppend element: Element) -> Index {
        if let index = index(where: f) {
            return index
        }

        append(element)
        return endIndex-1
    }
}

extension BalanceTreeNode {
    private mutating func add(amount: [Commodity: LedgerDouble]) {
        for (commodity, value) in amount {
            self.amount[commodity, or: 0] += value
        }
    }
    
    private mutating func insert(node: BalanceTreeNode, path: [String]) {
        guard path.count > 0 else { return }
        var remainingPath = path
        let namePrefix = remainingPath.remove(at: 0)
        add(amount: node.amount)

        let parentNode = remainingPath.isEmpty ? node : BalanceTreeNode(path: self.path + [namePrefix])
        let index = children.index(where: { $0.title == namePrefix }, orAppend: parentNode)
        children[index].insert(node: node, path: remainingPath)
    }
    
    mutating func insert(node: BalanceTreeNode) {
        insert(node: node, path: node.path)
    }
}
