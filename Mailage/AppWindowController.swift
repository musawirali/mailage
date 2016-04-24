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
import PromiseKit
import GTMOAuth2

class Message: Object {
    dynamic var msgId = ""
    dynamic var threadId = ""
    dynamic var processed = false
    
    override static func indexedProperties() -> [String] {
        return ["msgId"]
    }
}

class Attachment: Object {
    dynamic var imgId = ""
    dynamic var message: Message?
    dynamic var dateAdded = NSDate(timeIntervalSince1970: 0)
    
    override static func indexedProperties() -> [String] {
        return ["imgId"]
    }
}

class AppWindowController: NSWindowController {
    
    @IBOutlet weak var pauseBtn: NSButton!
    @IBOutlet weak var clearBtn: NSButton!
    
    // GMail info
    var userPofile: Dictionary<String, AnyObject>?
    
    // Dispatch queues
    let message_list_queue      = dispatch_queue_create("message_list", nil)
    let message_download_queue  = dispatch_queue_create("message_download", nil)
    
    // Fetch stats
    var fetchedTill: NSDate?
    
    // Download status
    var pausing = false
    var paused = false
    
    func onUserLoggedIn() {
        // Fetch profile
        self.fetchProfile()
        
        self.showWindow(self)
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }
    
    func onUserLoggedOut() {
        self.fetchedTill = nil
        self.userPofile = nil
        self.appVC()?.userEmailLabel.stringValue = "Not logged in"

        self.showWindow(self)
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }
    
    func fetchProfile() {
        let appDelegate = self.getAppDelegate()
        
        let req = NSMutableURLRequest(URL: NSURL(string: "https://www.googleapis.com/gmail/v1/users/me/profile")!)
        appDelegate.googleAuth.authorizeRequest(req) { err in
            if err == nil {
                firstly { () -> URLDataPromise in
                    self.appVC()?.userEmailLabel.stringValue = "Logging in ..."
                    return NSURLConnection.promise(req)
                }.then { (data) -> Dictionary<String, AnyObject>? in
                    if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                        return json as? Dictionary<String, AnyObject>
                    }
                    return nil
                }.then { (user_data) -> Void in
                    self.userPofile = user_data
                    if let email = self.userPofile?["emailAddress"] as? String {
                        self.appVC()?.userEmailLabel.stringValue = email
                    } else {
                        self.appVC()?.userEmailLabel.stringValue = "Unknown user"
                    }
                    
                    // Start fetching message list
                    dispatch_async(self.message_list_queue) {
                        self.startGetMessageList()
                    }
                    
                    // Start downloading messages
                    dispatch_async(self.message_download_queue, {
                        self.startDownloadMessages()
                    })
                }
            } else {
                // TODO: Send message to app delegate that we're logged out
                print("User logged out in middle")
                return
            }
        }
    }
    
    func updateMessageCount() {
        dispatch_async(dispatch_get_main_queue()) { 
            if let vc = self.contentViewController as? AppViewController {
                let realm = try! Realm()
                let msgCount = realm.objects(Message).count
                let processedCount = realm.objects(Message).filter("processed = true").count
                let imgCount = realm.objects(Attachment).count
                
                vc.msgCountLabel.stringValue = "\(processedCount)/\(msgCount) --> \(imgCount)"
            }
        }
    }
    
    func startGetMessageList() {
        let fetchDate = self.fetchedTill ?? NSDate(timeIntervalSince1970: 0)
        self.getMessages(nil, fetchDate: fetchDate)
    }
    
    func getMessages(nextPageToken: String?, fetchDate: NSDate) {
        let appDelegate = self.getAppDelegate()

        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        
        var urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages?q=filename:jpg OR filename:png OR filename:jpeg after:\(dateFormatter.stringFromDate(fetchDate))".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        if let token = nextPageToken {
            urlStr = urlStr + "&pageToken=\(token)"
        }
        
        let req = NSMutableURLRequest(URL: NSURL(string: urlStr)!);
        
        appDelegate.googleAuth.authorizeRequest(req) { err in
            if err == nil {
                firstly {
                    NSURLConnection.promise(req)
                }.then { (data) -> String? in
                    if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                        if let data = json as? Dictionary<String, AnyObject> {
                            let messages = (data["messages"] as? [Dictionary<String, AnyObject>]) ?? []
                            
                            // Save messages in Realm
                            let realm = try? Realm()
                            for message in messages {
                                let msg_id = message["id"] as! String
                                if let msgs = realm?.objects(Message).filter("msgId = '\(msg_id)'") {
                                    if msgs.count < 1 {
                                        let msg = Message()
                                        msg.msgId = msg_id
    
                                        try! realm?.write({
                                            realm?.add(msg)
                                        })
                                    }
                                }
                            }
                            
                            self.updateMessageCount()
                            return data["nextPageToken"] as? String
                        }
                    }
                    
                    return nil
                }.then { (next_page_token) -> Void in
                    // Have more pages to get
                    if let next_page_token = next_page_token {
                        dispatch_async(self.message_list_queue, {
                            self.getMessages(next_page_token, fetchDate: fetchDate)
                        })
                    } else { // No more pages. Wait a while and then queue up another message list sync
                        self.fetchedTill = NSDate()
                        if false {
                            let date_str = dateFormatter.stringFromDate(self.fetchedTill!)
                            let defaults = NSUserDefaults.standardUserDefaults()
                            defaults.setValue(date_str, forKey: "fetched-till")
                            defaults.synchronize()
                        }
                        
                        dispatch_promise { () in
                            assert(!NSThread.isMainThread())
                            sleep(10)
                        }.then(on: self.message_list_queue) { () in
                            self.startGetMessageList()
                        }
                    }
                }
            } else {
                // TODO: Send message to app delegate that we're logged out
                print("User logged out in middle of message fetch")
                return
            }
        }
    }
    
    func startDownloadMessages() {
        let realm = try! Realm()
        
        // Check for pause status
        if self.pausing {
            self.pausing = false
            self.paused = true
            dispatch_async(dispatch_get_main_queue(), {
                self.pauseBtn.title = "Resume"
                self.pauseBtn.enabled = true
                self.clearBtn.enabled = true
            })
        }
        
        
        // If we have an unprocessed message and are not paused, download it.
        let msg = realm.objects(Message).filter("processed = false").first
        if !self.paused && msg != nil {
            self.downloadMessageImages(msg!.msgId)
        } else { // otherwise wait and try again
            dispatch_promise { () in
                assert(!NSThread.isMainThread())
                sleep(10)
            }.then(on: self.message_download_queue) { () in
                self.startDownloadMessages()
            }
        }
    }
    
    func downloadMessageImages(msgId: String) {
        let appDelegate = self.getAppDelegate()

        let urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages/\(msgId)".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        let req = NSMutableURLRequest(URL: NSURL(string: urlStr!)!);

        appDelegate.googleAuth.authorizeRequest(req) { err in
            if err == nil {
                firstly { () -> URLDataPromise in
                    return NSURLConnection.promise(req)
                }.then { (data) -> Dictionary<String, AnyObject>? in
                    if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                        if let data = json as? Dictionary<String, AnyObject> {
                            return data["payload"] as? Dictionary<String, AnyObject>
                        }
                    }
                    return nil
                }.then { (payload) -> [Dictionary<String, AnyObject>] in
                    print("Started:", msgId)
                    if let msg = payload {
                        var downloads = Array<Dictionary<String, AnyObject>>()
                        self.parseMessage(msgId, msg: msg, downloads: &downloads)
                        return downloads
                    }
                    return []
                }.then { (vals) -> Promise<AnyObject?> in
                    var prom = dispatch_promise { () -> AnyObject? in
                        return nil
                    }
                    
                    print("Items:", vals.count)
                    dispatch_async(dispatch_get_main_queue(), { 
                        if let vc = self.contentViewController as? AppViewController {
                            vc.progressBar.minValue = 0
                            vc.progressBar.maxValue = Double(vals.count + 1)
                            vc.progressBar.doubleValue = 1
                        }
                    })
                    
                    for (idx, msg) in vals.enumerate() {
                        prom = prom.thenInBackground {_ in
                            self.downloadMessage(idx, msgId: msgId, msg: msg)
                        }
                    }
                    
                    return prom
                }.then(on: self.message_download_queue) { (vals) -> Void in
                    let realm = try! Realm()
                    if let theMsg = realm.objects(Message).filter("msgId = '\(msgId)'").first {
                        try! realm.write({
                            theMsg.processed = true
                        })
                    }
                    
                    self.updateMessageCount()
                    self.startDownloadMessages()
                }
            } else {
                // TODO: Send message to app delegate that we're logged out
                print("User logged out in middle")
                return
            }
        }
    }
    
    func parseMessage(msg_id: String, msg: Dictionary<String, AnyObject>, inout downloads: [Dictionary<String, AnyObject>]) {
        
        let regexp = try? NSRegularExpression(pattern: "^image", options: NSRegularExpressionOptions.CaseInsensitive)
        let mimeType = msg["mimeType"] as! String
        if let matches = regexp?.matchesInString(mimeType, options: NSMatchingOptions.Anchored, range: NSMakeRange(0, (mimeType as NSString).length)) {
            if matches.count > 0 {
                downloads.append(msg)
            }
        }
        
        if let parts = msg["parts"] as? [Dictionary<String, AnyObject>] {
            for part in parts {
                self.parseMessage(msg_id, msg: part, downloads: &downloads)
            }
        }
    }
    
    func downloadMessage(msgNum: Int, msgId: String, msg: Dictionary<String, AnyObject>) -> Promise<AnyObject?> {
        let appDelegate = self.getAppDelegate()
        
        if let body = msg["body"] as? Dictionary<String, AnyObject> {
            if let attachmentId = body["attachmentId"] as? String {
                let urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages/\(msgId)/attachments/\(attachmentId)".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
                let req = NSMutableURLRequest(URL: NSURL(string: urlStr!)!);
                
                return Promise { fulfill, reject in
                    appDelegate.googleAuth.authorizeRequest(req) { err in
                        fulfill(req)
                    }
                }.thenInBackground { req in
                    return NSURLConnection.promise(req)
                }.thenInBackground { (data) -> Dictionary<String, AnyObject>? in
                    print("Downloaded")
                    if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                        return json as? Dictionary<String, AnyObject>
                    }
                    return nil
                }.thenInBackground { (img_data) -> AnyObject? in
                    if let img_str = img_data?["data"] as? String {
                        self.processImage(msgId, img_data: img_str)
                    }
                    print("Processed")
                    dispatch_async(dispatch_get_main_queue(), {
                        if let vc = self.contentViewController as? AppViewController {
                            vc.progressBar.doubleValue = Double(msgNum + 2)
                        }
                    })
                    return nil
                }
            }
        }

        return dispatch_promise {
        }.thenInBackground { (val) -> AnyObject? in
            print("Empty", msgId)
            return nil
        }
    }
    
    func processImage(msgId: String, img_data: String) {
        let md5 = img_data.md5()
        
        let newstr = img_data.stringByReplacingOccurrencesOfString("_", withString: "/", options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil)
        let newstr2 = newstr.stringByReplacingOccurrencesOfString("-", withString: "+", options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil)
        
        if let ns_data = NSData(base64EncodedString: newstr2, options: NSDataBase64DecodingOptions.IgnoreUnknownCharacters) {
            if let img = NSImage(data: ns_data) {
                if let imgRep = img.representations.first as? NSBitmapImageRep {
                    let props = Dictionary<String, AnyObject>();
                    let img_file_data = imgRep.representationUsingType(.NSPNGFileType, properties: props);
                    
                    let fm = NSFileManager.defaultManager()
                    let urls = fm.URLsForDirectory(NSSearchPathDirectory.PicturesDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
                    if let url = urls.first {
                        if !fm.fileExistsAtPath(url.URLByAppendingPathComponent("mailage").path!) {
                            try! fm.createDirectoryAtURL(url.URLByAppendingPathComponent("mailage"), withIntermediateDirectories: false, attributes: nil)
                        }
                        img_file_data?.writeToURL(url.URLByAppendingPathComponent("mailage/\(md5).png"), atomically: false);
                        
                        let realm = try! Realm()
                        if realm.objects(Attachment).filter("imgId = '\(md5)'").count < 1 {
                            let attachment = Attachment();
                            attachment.imgId = md5
                            attachment.message = realm.objects(Message).filter("msgId = '\(msgId)'").first
                            attachment.dateAdded = NSDate()
                            
                            try! realm.write({
                                realm.add(attachment)
                            })
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), {
                            if let vc = self.contentViewController as? AppViewController {
                                vc.collectionView.reloadData()
                            }
                        })
                    }
                }

//                self.images.append(img)
//                var set = Set<NSIndexPath>()
//                set.insert(NSIndexPath(forItem: self.images.count - 1, inSection: 0))
//                
//                dispatch_async(dispatch_get_main_queue(), {
//                    if let vc = self.appWC?.contentViewController as? AppViewController {
//                        vc.collectionView.insertItemsAtIndexPaths(set)
//                    }
//                })
            }
        }
        
//        let attachment = Attachment()
//        attachment.imgId = md5
//        
//        try! realm.write({
//            realm.add(attachment)
//        })
    }
    
    func getAppDelegate() -> AppDelegate {
        return NSApplication.sharedApplication().delegate as! AppDelegate
    }
    
    func appVC() -> AppViewController? {
        return self.contentViewController as? AppViewController
    }
    
    @IBAction func onPause(sender: AnyObject) {
        if (!self.paused) {
            self.pausing = true
            self.pauseBtn.title = "Pausing ..."
            self.pauseBtn.enabled = false
        } else {
            self.paused = false
            self.clearBtn.enabled = false
            self.pauseBtn.title = "Pause"
        }
    }
    
    @IBAction func onClear(sender: AnyObject) {
        self.clearBtn.enabled = false
        self.clearBtn.title = "Clearing..."
        self.pauseBtn.enabled = false
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setValue(nil, forKey: "fetched-till")
            defaults.synchronize()

            let realm = try! Realm()
            let msgs = realm.objects(Message)
            let imgs = realm.objects(Attachment)
            try! realm.write({
                //for msg in msgs {
                //    msg.processed = false
                //}
                realm.delete(imgs)
                realm.delete(msgs)
            })
            
            self.updateMessageCount()
            
            dispatch_async(dispatch_get_main_queue(), {
                self.clearBtn.title = "Clear"
                self.clearBtn.enabled = true
                self.pauseBtn.enabled = true
                
                self.fetchedTill = nil
            })
        }
        
//            let imgs = realm.objects(Attachment)
//            try! realm.write({
//                realm.delete(imgs)
//            })
//            
//            appDelegate.images.removeAll()
//            if let vc = self.contentViewController as? AppViewController {
//                vc.collectionView.reloadData()
//            }
    }
}