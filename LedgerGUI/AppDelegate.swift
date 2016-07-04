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
    var windowController: NSWindowController?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        windowController = NSWindowController(window: window)
        let registerViewController = RegisterViewController()
//        windowController?.contentViewController = registerViewController
        window.contentViewController = registerViewController
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }


}

