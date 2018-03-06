//
//  LedgerDocument.swift
//  LedgerGUI
//
//  Created by Florian on 06/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa


final class LedgerDocument: NSDocument {
    var controller = LedgerDocumentController()
    
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
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Storyboard"), bundle: nil)
        let wc = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "WindowController")) as! LedgerWindowController
        wc.document = self
        addWindowController(wc)
        wc.showWindow(nil)
        controller.windowController = wc
    }
}


