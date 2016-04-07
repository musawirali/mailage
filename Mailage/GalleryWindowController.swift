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
    
    @IBOutlet weak var sideBarView: NSVisualEffectView!
    @IBOutlet weak var statusText: NSTextField!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var countText: NSTextField!
    
    @IBOutlet weak var pauseBtn: NSButton!
    @IBOutlet weak var syncText: NSTextField!
    
    var isPaused = false

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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.sideBarView.wantsLayer = true
        self.sideBarView.material = NSVisualEffectMaterial.Sidebar
        self.sideBarView.blendingMode = NSVisualEffectBlendingMode.BehindWindow
        self.sideBarView.state = NSVisualEffectState.Active
    }
    
    func updateStatus(userProfile: Dictionary<String, AnyObject>?) {
        if let profile = userProfile {
            let email = profile["emailAddress"] as! String
            self.statusText.stringValue = "Logged in as \(email)"
        } else {
            self.statusText.stringValue = "Not logged in"
        }
    }
    
    @IBAction func pauseSync(sender: AnyObject) {
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            if (self.isPaused) {
                dispatch_resume(appDelegate.download_msg_queue)
            } else {
                dispatch_suspend(appDelegate.download_msg_queue)
            }
            self.isPaused = !self.isPaused
            
            self.pauseBtn.title = self.isPaused ? "Resume" : "Pause"
        }
    }
    
}