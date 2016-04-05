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
    
    let message_queue = dispatch_queue_create("message_q", nil)

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
        
        self.googleAuth = GTMOAuth2WindowController.authForGoogleFromKeychainForName(self.keychainToken, clientID: self.clientId, clientSecret: self.clientSecret)
        if (!self.googleAuth.canAuthorize) {
            self.loginMenuItem?.title = self.loginMenuTitle
        } else {
            self.loginMenuItem?.title = "Logout"
            self.fetchProfile()
        }
        
        self.onGalleryClick(self)
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
        })
        
        self.getMessages()
    }
    
    func getMessages() {
        let urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages?q=filename:jpg OR filename:png OR filename:jpeg".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        let req = NSMutableURLRequest(URL: NSURL(string: urlStr!)!);
        let fetcher = GTMSessionFetcher(request: req)
        fetcher.authorizer = self.googleAuth
        fetcher.beginFetchWithCompletionHandler({ (data, err) in
            if let data = data {
                if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                    if let data = json as? Dictionary<String, AnyObject> {
                        if let messages = data["messages"] as? [Dictionary<String, AnyObject>] {
                            for message in messages {
                                dispatch_async(self.message_queue, {
                                    self.getMessage(message)
                                })
                            }
                        }
                    }
                }
            }
        })
    }
    
    func getMessage(msg: Dictionary<String, AnyObject>) {
        let msg_id = msg["id"] as! String
        
        let urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages/\(msg_id)".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        let req = NSMutableURLRequest(URL: NSURL(string: urlStr!)!);
        let fetcher = GTMSessionFetcher(request: req)
        fetcher.authorizer = self.googleAuth
        fetcher.beginFetchWithCompletionHandler({ (data, err) in
            if let data = data {
                if let json = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) {
                    if let data = json as? Dictionary<String, AnyObject> {
                        if let payload = data["payload"] as? Dictionary<String, AnyObject> {
                            self.parseMessage(msg_id, msg: payload)
                        }
                    }
                }
            }
            dispatch_resume(self.message_queue)
        })
        
        dispatch_suspend(self.message_queue)
    }
    
    func parseMessage(msg_id: String, msg: Dictionary<String, AnyObject>) {
        let regexp = try? NSRegularExpression(pattern: "^image", options: NSRegularExpressionOptions.CaseInsensitive)
        let mimeType = msg["mimeType"] as! String
        if let matches = regexp?.matchesInString(mimeType, options: NSMatchingOptions.Anchored, range: NSMakeRange(0, (mimeType as NSString).length)) {
            if matches.count > 0 {
                self.downloadPart(msg_id, part: msg)
            }
        }
        
        if let parts = msg["parts"] as? [Dictionary<String, AnyObject>] {
            for part in parts {
                self.parseMessage(msg_id, msg: part)
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

