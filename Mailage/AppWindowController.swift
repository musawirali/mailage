//
//  AppWindowController.swift
//  Mailage
//
//  Created by Musawir Shah on 4/7/16.
//  Copyright © 2016 YourMechanic. All rights reserved.
//

import Foundation
import Cocoa
import RealmSwift

class AppWindowController: NSWindowController {
    
    @IBOutlet weak var pauseBtn: NSButton!
    @IBOutlet weak var clearBtn: NSButton!
    
    override func windowDidLoad() {
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            self.pauseBtn.title = appDelegate.isPaused ? "Resume" : "Pause"
        }
    }
    
    @IBAction func onPause(sender: AnyObject) {
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            if (appDelegate.isPaused) {
                dispatch_resume(appDelegate.download_msg_queue)
            } else {
                dispatch_suspend(appDelegate.download_msg_queue)
            }
            appDelegate.isPaused = !appDelegate.isPaused
            
            self.pauseBtn.title = appDelegate.isPaused ? "Resume" : "Pause"
        }
    }
    
    @IBAction func onClear(sender: AnyObject) {
        self.onPause(sender)
        
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            let realm = try! Realm()
            let msgs = realm.objects(Message)
            try! realm.write({
                for msg in msgs {
                    msg.processed = false
                }
            })
            
            let imgs = realm.objects(Attachment)
            try! realm.write({
                realm.delete(imgs)
            })
            
            appDelegate.images.removeAll()
            if let vc = self.contentViewController as? AppViewController {
                vc.collectionView.reloadData()
            }
        }
        
        self.onPause(sender)
    }
}