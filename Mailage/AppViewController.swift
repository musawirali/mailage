//
//  AppViewController.swift
//  Mailage
//
//  Created by Musawir Shah on 4/7/16.
//  Copyright © 2016 YourMechanic. All rights reserved.
//

import Foundation
import Cocoa
import RealmSwift

class AppViewController: NSViewController, NSCollectionViewDataSource {
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var msgCountLabel: NSTextField!
    @IBOutlet weak var userEmailLabel: NSTextField!
    @IBOutlet weak var collectionView: NSCollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.collectionView.registerNib(NSNib(nibNamed: "ImageCollectionViewItem", bundle: nil), forItemWithIdentifier: "CollectionViewItem")
    }

    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let realm = try? Realm()
        
        return realm?.objects(Attachment).count ?? 0
    }
    
    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let cvi = self.collectionView.makeItemWithIdentifier("CollectionViewItem", forIndexPath: indexPath)
        
        dispatch_async(dispatch_get_main_queue()) {
            let realm = try! Realm()
            let img = realm.objects(Attachment).sorted("dateAdded", ascending: true)[indexPath.item]

            let fm = NSFileManager.defaultManager()
            let urls = fm.URLsForDirectory(NSSearchPathDirectory.PicturesDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
            if let url = urls.first {
                if let path = url.URLByAppendingPathComponent("mailage/\(img.imgId).png").path {
                    if let ns_img = NSImage(contentsOfFile: path) {
                        cvi.imageView?.image = ns_img
                    }
                }
            }
        }
//        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
//            cvi.imageView?.image = appDelegate.images[indexPath.item]
//        }
        
        return cvi
    }
    
}