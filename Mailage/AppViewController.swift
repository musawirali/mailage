//
//  AppViewController.swift
//  Mailage
//
//  Created by Musawir Shah on 4/7/16.
//  Copyright © 2016 YourMechanic. All rights reserved.
//

import Foundation
import Cocoa

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
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            return appDelegate.images.count
        }
        return 0
    }
    
    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let cvi = self.collectionView.makeItemWithIdentifier("CollectionViewItem", forIndexPath: indexPath)
        
        if let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate {
            cvi.imageView?.image = appDelegate.images[indexPath.item]
        }
        
        return cvi
    }
    
}