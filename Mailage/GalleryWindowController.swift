//
//  GalleryWindowController.swift
//  Mailage
//
//  Created by Musawir Shah on 4/3/16.
//  Copyright © 2016 YourMechanic. All rights reserved.
//

import Foundation
import Cocoa

class GalleryWindowController: NSWindowController {
    
    class func CreateWC() -> GalleryWindowController? {
        
        var objects: NSArray?
        NSBundle.mainBundle().loadNibNamed("GalleryWindow", owner: self, topLevelObjects: &objects)
        if let objects = objects {
            for object in objects {
                if let wc = object as? GalleryWindowController {
                    return wc
                }
            }
        }
        
        return nil
    }
}