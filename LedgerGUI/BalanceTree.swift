//
//  BalanceTree.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 07-07-16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation

extension Ledger {
    var balanceTree: [BalanceTreeNode] {
        let sortedAccounts = Array(balance).sorted { p1, p2 in
            return p1.key < p2.key
        }
        
        var rootItem = BalanceTreeNode(accountName: nil, amount: MultiCommodityAmount())
        
        for account in sortedAccounts {
            let node = BalanceTreeNode(accountName: account.key, amount: account.value)
            rootItem.insert(node: node)
        }
        
        return rootItem.children
    }
}


struct BalanceTreeNode: Tree {
    var amount: MultiCommodityAmount
    var children: [BalanceTreeNode] = []
    var path: [String]
    
    var title: String {
        return path.last ?? ""
    }

    var accountName: String {
        return path.joined(separator: ":")
    }

    init(accountName: String?, amount: MultiCommodityAmount) {
        path = accountName?.components(separatedBy: ":") ?? []
        self.amount = amount
    }
    
    init(path: [String], amount: MultiCommodityAmount = MultiCommodityAmount()) {
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
    
    var decompose: (Element, [Element])? {
        guard !isEmpty else { return nil }
        var copy = self
        let firstElement = copy.remove(at: 0)
        return (firstElement, copy)
    }
}

extension BalanceTreeNode {
    private mutating func insert(node: BalanceTreeNode, path: [String]) {
        guard let (namePrefix, remainingPath) = path.decompose else { return }

        self.amount += node.amount

        let parentNode = remainingPath.isEmpty ? node : BalanceTreeNode(path: self.path + [namePrefix])
        let index = children.index(where: { $0.title == namePrefix }, orAppend: parentNode)
        children[index].insert(node: node, path: remainingPath)
    }
    
    mutating func insert(node: BalanceTreeNode) {
        insert(node: node, path: node.path)
    }
}
