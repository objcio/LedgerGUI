//
//  UIHelpers.swift
//  LedgerGUI
//
//  Created by Florian on 06/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Cocoa

extension NSFont {
    var italic: NSFont {
        return NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
    }
}

extension Amount {
    var displayValue: String {
        let formatter = NumberFormatter()
        formatter.currencySymbol = commodity.value
        formatter.numberStyle = .currencyAccounting
        return formatter.string(from: number.value as NSNumber) ?? ""
    }
    
    var color: NSColor {
        return isNegative ? .red : .black
    }
}

extension NSView {
    func constrainEdges(toMarginOf otherView: NSView) {
        translatesAutoresizingMaskIntoConstraints = false
        
        topAnchor.constraint(equalTo: otherView.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: otherView.bottomAnchor).isActive = true
        leftAnchor.constraint(equalTo: otherView.leftAnchor).isActive = true
        rightAnchor.constraint(equalTo: otherView.rightAnchor).isActive = true
    }
}


