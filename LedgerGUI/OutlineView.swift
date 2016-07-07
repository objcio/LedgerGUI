//
//  OutlineView.swift
//  LedgerGUI
//
//  Created by Chris Eidhof on 07-07-16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

protocol Tree {
    var children: [Self] { get }
}


private final class TreeBox<A: Tree> {
    let unbox: A
    var children: [TreeBox<A>] // TODO: it would be nice to compute these dynamically, but we get a retain problem.
    
    init(_ item: A) {
        self.unbox = item
        self.children = item.children.map(TreeBox.init)
    }
}

class OutlineDataSourceAndDelegate<A: Tree, Cell: NSTableCellView>: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource {
    private var tree: [TreeBox<A>] = []
    var configure: (A, Cell) -> () = { _ in }
    var didSelect: (A?) -> () = { _ in }
    
    var rootItems: [A] {
        get {
            return tree.map { $0.unbox }
        }
        set {
            tree = newValue.map(TreeBox.init)
        }
    }
    
    init(configure: (A, Cell) -> ()) {
        self.configure = configure
    }
    
    let cellIdentifier = "Cell"
    
    
    private func children(item: AnyObject?) -> [TreeBox<A>] {
        guard let item = item else { return tree }
        return (item as! TreeBox<A>).children
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        return children(item: item).count
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return children(item: item).count > 0
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let outlineView = notification.object as! NSOutlineView
        didSelect((outlineView.item(atRow: outlineView.selectedRow) as? TreeBox<A>)?.unbox)
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        return children(item: item)[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        guard let boxed = item as? TreeBox<A> else {
            fatalError("Expected a box, got an \(item)")
        }
        let cell = outlineView.make(withIdentifier: cellIdentifier, owner: self)! as! Cell
        configure(boxed.unbox, cell)
        return cell
    }
    
}
