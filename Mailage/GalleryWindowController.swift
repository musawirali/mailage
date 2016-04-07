//
//  GalleryWindowController.swift
//  Mailage
//
//  Created by Musawir Shah on 4/3/16.
//  Copyright © 2016 YourMechanic. All rights reserved.
//

import Foundation
import Cocoa
import RealmSwift

class GalleryWindowController: NSWindowController, NSCollectionViewDataSource {
    
    @IBOutlet weak var sideBarView: NSVisualEffectView!
    @IBOutlet weak var statusText: NSTextField!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var countText: NSTextField!
    
    @IBOutlet weak var pauseBtn: NSButton!
    @IBOutlet weak var syncText: NSTextField!
    
    @IBOutlet weak var collectionView: NSCollectionView!
    
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
        
        self.collectionView.registerNib(NSNib(nibNamed: "ImageCollectionViewItem", bundle: nil), forItemWithIdentifier: "galleryItem")
        //self.collectionView.registerNib(NSNib(nibNamed: "ImageCollectionViewItem") forItemWithIdentifier: "galleryItem")
    }
    
    func updateStatus(userProfile: Dictionary<String, AnyObject>?) {
        if let profile = userProfile {
            let email = profile["emailAddress"] as! String
            self.statusText.stringValue = "Logged in as \(email)"
        } else {
            self.statusText.stringValue = "Not logged in"
        }
    }
    
    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            return appDelegate.images.count
        }
        return 0
    }
    
    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let cvi = self.collectionView.makeItemWithIdentifier("galleryItem", forIndexPath: indexPath)
        
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            cvi.imageView?.image = appDelegate.images[indexPath.item]
        }

        return cvi
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
    
    @IBAction func clearEverything(sender: AnyObject) {
        self.pauseSync(sender)

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
            self.collectionView.reloadData()
        }
        
        self.pauseSync(sender)
    }
    
}