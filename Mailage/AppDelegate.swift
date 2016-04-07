//
//  AppDelegate.swift
//  Mailage
//
//  Created by Musawir Shah on 4/1/16.
//  Copyright © 2016 YourMechanic. All rights reserved.
//

import Cocoa
import WebKit
import GTMOAuth2
import RealmSwift

class Message: Object {
    dynamic var msgId = ""
    dynamic var threadId = ""
    dynamic var processed = false
    
    override static func indexedProperties() -> [String] {
        return ["msgId"]
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var loginWC: GTMOAuth2WindowController?
    var galleryWC: GalleryWindowController?
    var googleAuth: GTMOAuth2Authentication! = nil
    
    var userProfile: Dictionary<String, AnyObject>?
    
    var loginMenuItem: NSMenuItem?
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    
    let keychainToken = "Mailage Mac"
    let clientId = "653085801125-tn3i386peicmjia3e7m1joe9jf0vclsd.apps.googleusercontent.com"
    let clientSecret = "0aZQX6Q1Yx35wksuHYwmmkkL"
    let loginMenuTitle = "Login"
    
    var message_queue = dispatch_queue_create("message_q", nil)
    var download_msg_queue = dispatch_queue_create("download_m_q", nil)
    var download_att_queue = dispatch_queue_create("download_a_q", nil)
    
    var fetchedTill: NSDate?
    var sync_queue = dispatch_queue_create("sync_q", nil)
    
    var stats_update_queue = dispatch_queue_create("stats_q", nil)
    
    //var isPaused = false

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Create menu
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
        }
        
        let menu = NSMenu(title: "Mailage")
        self.loginMenuItem = NSMenuItem(title: "Login", action: #selector(onLoginClick), keyEquivalent: "")
        
        menu.addItemWithTitle("Gallery", action: #selector(onGalleryClick), keyEquivalent: "")
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItem(self.loginMenuItem!)
        menu.addItemWithTitle("Quit", action: #selector(onQuitClick), keyEquivalent: "q")

        statusItem.menu = menu
        
        // Grab last fetch date
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let defaults = NSUserDefaults.standardUserDefaults()
        if let fetch_date = defaults.stringForKey("fetched-till") {
            self.fetchedTill = dateFormatter.dateFromString(fetch_date)
        }
        
        // Check auth
        self.googleAuth = GTMOAuth2WindowController.authForGoogleFromKeychainForName(self.keychainToken, clientID: self.clientId, clientSecret: self.clientSecret)
        if (!self.googleAuth.canAuthorize) {
            self.loginMenuItem?.title = self.loginMenuTitle
        } else {
            self.loginMenuItem?.title = "Logout"
            self.fetchProfile()
        }
        
        // Open gallery
        self.onGalleryClick(self)
    }
    
    func updateStats() {
        dispatch_async(stats_update_queue) {
            let realm = try! Realm()
            let m = realm.objects(Message).count;
            let p = realm.objects(Message).filter("processed = false").count
            let d = realm.objects(Message).filter("processed = true").count
            self.galleryWC?.countText.stringValue = "M: \(m)    P: \(p)    D:\(d)"
        }
    }
    
    func fetchProfile() {
        if !self.googleAuth.canAuthorize {
            self.userProfile = nil
            self.galleryWC?.updateStatus(self.userProfile)
            return
        }

        let req = NSMutableURLRequest(URL: NSURL(string: "https://www.googleapis.com/gmail/v1/users/me/profile")!)
        let fetcher = GTMSessionFetcher(request: req)
        fetcher.authorizer = self.googleAuth
        fetcher.beginFetchWithCompletionHandler({ (data, err) in
            if let data = data {
                if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                    self.userProfile = json as? Dictionary<String, AnyObject>
                    self.galleryWC?.updateStatus(self.userProfile)
                }
            }
            
            // Start message sync loop
            dispatch_async(self.sync_queue) {
                self.startGetMessages()
            }
            // Start message download loop
            dispatch_async(self.download_msg_queue, {
                self.startDownloadMessages()
            })
        })
    }
    
    func startDownloadMessages() {
        if !self.googleAuth.canAuthorize {
            print("Cannot sync, not logged in. Exiting download msg queue")
            return
        }
        
        /*
        if (self.isPaused) {
            dispatch_async(self.download_msg_queue) {
                sleep(10)
                self.startDownloadMessages()
            }
            return
        }*/
        
        let realm = try! Realm()
        if let msg = realm.objects(Message).filter("processed = false").first {
            self.getMessage(msg)
        }
    }
    
    func startGetMessages() {
        if !self.googleAuth.canAuthorize {
            print("Cannot sync, not logged in. Exiting get msg queue")
            return
        }
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        
        let fetchDate = self.fetchedTill ?? NSDate(timeIntervalSince1970: 0)
        self.galleryWC?.syncText.stringValue = "Sync'ing messages from date: \(dateFormatter.stringFromDate(fetchDate))"
        
        self.getMessages(nil, fetchDate: fetchDate)
    }
    
    func getMessages(nextPageToken: String?, fetchDate: NSDate) {
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        
        var urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages?q=filename:jpg OR filename:png OR filename:jpeg after:\(dateFormatter.stringFromDate(fetchDate))".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        if let token = nextPageToken {
            urlStr = urlStr + "&pageToken=\(token)"
        }

        let req = NSMutableURLRequest(URL: NSURL(string: urlStr)!);
        let fetcher = GTMSessionFetcher(request: req)
        fetcher.authorizer = self.googleAuth
        fetcher.beginFetchWithCompletionHandler({ (data, err) in
            if let data = data {
                if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                    if let data = json as? Dictionary<String, AnyObject> {
                        if let messages = data["messages"] as? [Dictionary<String, AnyObject>] {
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
                        }
                        
                        self.updateStats()
                        
                        if let nextPageToken = data["nextPageToken"] as? String {
                            dispatch_async(self.message_queue, {
                                self.getMessages(nextPageToken, fetchDate: fetchDate)
                            })
                        } else {
                            self.fetchedTill = NSDate()
                            let date_str = dateFormatter.stringFromDate(self.fetchedTill!)
                            
                            let defaults = NSUserDefaults.standardUserDefaults()
                            defaults.setValue(date_str, forKey: "fetched-till")
                            defaults.synchronize()
                            
                            self.galleryWC?.syncText.stringValue = "Sync'ed"
                            
                            dispatch_async(self.sync_queue) {
                                sleep(10)
                                self.startGetMessages()
                            }
                        }
                    }
                }
            }
        })
    }
    
    func getMessage(msg: Message) {
        let msg_id = String(msg.msgId)
        let urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages/\(msg_id)".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        let req = NSMutableURLRequest(URL: NSURL(string: urlStr!)!);
        let fetcher = GTMSessionFetcher(request: req)
        fetcher.authorizer = self.googleAuth
        fetcher.beginFetchWithCompletionHandler({ (data, err) in
            if let data = data {
                if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                    if let data = json as? Dictionary<String, AnyObject> {
                        if let payload = data["payload"] as? Dictionary<String, AnyObject> {
                            self.parseMessage(msg_id, msg: payload, level: 0)
                        }
                    }
                }
            }
        })
    }
    
    func parseMessage(msg_id: String, msg: Dictionary<String, AnyObject>, level: Int) {
        let regexp = try? NSRegularExpression(pattern: "^image", options: NSRegularExpressionOptions.CaseInsensitive)
        let mimeType = msg["mimeType"] as! String
        if let matches = regexp?.matchesInString(mimeType, options: NSMatchingOptions.Anchored, range: NSMakeRange(0, (mimeType as NSString).length)) {
            if matches.count > 0 {
                dispatch_async(self.download_att_queue, {
                    self.downloadPart(msg_id, part: msg)
                })
            }
        }
        
        if let parts = msg["parts"] as? [Dictionary<String, AnyObject>] {
            for part in parts {
                self.parseMessage(msg_id, msg: part, level: level + 1)
            }
        }
        
        if (level == 0) {
            dispatch_async(self.download_att_queue) {
                let realm = try! Realm()
                if let theMsg = realm.objects(Message).filter("msgId = '\(msg_id)'").first {
                    try! realm.write({ 
                        theMsg.processed = true
                    })
                }
                
                self.updateStats()
                
                dispatch_async(self.download_msg_queue, {
                    self.startDownloadMessages()
                })
            }
        }
    }
    
    func downloadPart(msg_id: String, part: Dictionary<String, AnyObject>) {
        if let body = part["body"] as? Dictionary<String, AnyObject> {
            if let attachmentId = body["attachmentId"] as? String {
                let urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages/\(msg_id)/attachments/\(attachmentId)".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
                let req = NSMutableURLRequest(URL: NSURL(string: urlStr!)!);
                let fetcher = GTMSessionFetcher(request: req)
                fetcher.authorizer = self.googleAuth
                
                dispatch_suspend(self.download_att_queue)

                fetcher.beginFetchWithCompletionHandler({ (data, err) in
                    if let data = data {
                        if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)) {
                            if let data = json as? Dictionary<String, AnyObject> {
                                if let img_data = data["data"] as? String {
                                    
                                    let newstr = img_data.stringByReplacingOccurrencesOfString("_", withString: "/", options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil)
                                    let newstr2 = newstr.stringByReplacingOccurrencesOfString("-", withString: "+", options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil)
                                    
                                    if let ns_data = NSData(base64EncodedString: newstr2, options: NSDataBase64DecodingOptions.IgnoreUnknownCharacters) {
                                        if let img = NSImage(data: ns_data) {
                                            self.galleryWC?.imageView.image = img
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    dispatch_resume(self.download_att_queue)
                })
            }
        }
    }

    func onQuitClick(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(nil)
    }

    func onLoginClick(sender: AnyObject) {
        // Logging out?
        if self.loginMenuItem?.title != self.loginMenuTitle {
            GTMOAuth2WindowController.removeAuthFromKeychainForName(self.keychainToken)
            GTMOAuth2WindowController.revokeTokenForGoogleAuthentication(self.googleAuth)
            
            self.loginMenuItem?.title = self.loginMenuTitle
            
            self.fetchProfile()
            NSApplication.sharedApplication().activateIgnoringOtherApps(true)
            return
        }
        
        // Logging in
        if (self.loginWC == nil) {
            self.loginWC = GTMOAuth2WindowController(scope: "https://www.googleapis.com/auth/gmail.readonly", clientID: self.clientId, clientSecret: self.clientSecret, keychainItemName: self.keychainToken, resourceBundle: NSBundle(forClass: GTMOAuth2WindowController.self))
            self.loginWC?.initialHTMLString = "Authentication for Mailage"
        }
        self.loginWC?.signInSheetModalForWindow(nil, completionHandler: { (auth, err) in
            self.googleAuth = auth
            if (self.googleAuth.canAuthorize) {
                self.fetchProfile()
            } else {
                print("not authorized")
            }
        })
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }

    func onGalleryClick(sender: AnyObject) {
        if (self.galleryWC == nil) {
            self.galleryWC = GalleryWindowController.CreateWC()
        }
        self.galleryWC?.showWindow(sender)
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

