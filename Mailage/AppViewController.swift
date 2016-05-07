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
import Quartz

class ImageItem: NSObject {
    var imgId: String = ""
    
    init(idx: Int) {
        let realm = try! Realm()
        let img = realm.objects(Attachment).sorted("dateAdded", ascending: true)[idx]
        self.imgId = img.imgId
    }
    
    func imgUrl() -> NSURL {
        let fm = NSFileManager.defaultManager()
        let urls = fm.URLsForDirectory(NSSearchPathDirectory.PicturesDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
        if let url = urls.first {
            return url.URLByAppendingPathComponent("mailage/\(self.imgId).png")
        }
        
        return NSURL()
    }
    
    override func imageRepresentationType() -> String! {
        return IKImageBrowserNSImageRepresentationType
    }
    
    override func imageRepresentation() -> AnyObject! {
        let fm = NSFileManager.defaultManager()
        let urls = fm.URLsForDirectory(NSSearchPathDirectory.PicturesDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
        if let url = urls.first {
            if let path = url.URLByAppendingPathComponent("mailage/\(self.imgId).png").path {
                if let ns_img = NSImage(contentsOfFile: path) {
                    return ns_img;
                }
            }
        }
        return NSImage();
    }
    
    override func imageUID() -> String! {
        return self.imgId
    }
}

class AppViewController: NSViewController, NSCollectionViewDataSource {
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var msgCountLabel: NSTextField!
    @IBOutlet weak var userEmailLabel: NSTextField!
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var imgBrowser: IKImageBrowserView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func numberOfItemsInImageBrowser(aBrowser: IKImageBrowserView!) -> Int {
        let realm = try? Realm()
        
        return realm?.objects(Attachment).count ?? 0
    }

    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        let realm = try? Realm()
        
        return realm?.objects(Attachment).count ?? 0
    }
    
    override func imageBrowser(aBrowser: IKImageBrowserView!, itemAtIndex index: Int) -> AnyObject! {
        return ImageItem(idx: index)
    }
    
    override func imageBrowser(aBrowser: IKImageBrowserView!, writeItemsAtIndexes itemIndexes: NSIndexSet!, toPasteboard pasteboard: NSPasteboard!) -> Int {
        
        var imgs = Array<NSURL>();
        for idx in itemIndexes {
            let img = ImageItem(idx: idx)
            imgs.append(img.imgUrl())
        }
        
        pasteboard.clearContents()
        pasteboard.writeObjects(imgs)
        return imgs.count
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