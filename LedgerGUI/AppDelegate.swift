//
//  AppDelegate.swift
//  LedgerGUI
//
//  Created by Florian on 22/06/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        typealias MyParser = FastParser
        let path = "/Users/chris/objc.io/LedgerGUI/sample.txt"
        let contents = try! String(contentsOfFile: path)
        let result = parse(string: contents)
        print("Done")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

