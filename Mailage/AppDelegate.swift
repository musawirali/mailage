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
import CryptoSwift
import PromiseKit


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    // Window controllers
    var appWC: AppWindowController?
    var loginWC: GTMOAuth2WindowController?
    
    // Google auth object
    var googleAuth: GTMOAuth2Authentication! = nil
    
    // Google API config
    let keychainToken = "Mailage Mac"
    let clientId = "653085801125-tn3i386peicmjia3e7m1joe9jf0vclsd.apps.googleusercontent.com"
    let clientSecret = "0aZQX6Q1Yx35wksuHYwmmkkL"

    // Status menu items
    var loginMenuItem: NSMenuItem?
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    let loginMenuTitle = "Login"
    
    // User config
    var lastSyncDate: NSDate?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        /*
        let fm = NSFileManager.defaultManager()
        let urls = fm.URLsForDirectory(NSSearchPathDirectory.PicturesDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
        for url in urls {
            print(url.URLByAppendingPathComponent("mailage").absoluteString)
        }*/
        
        // Create status menu
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
        
        // Grab last sync date
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let defaults = NSUserDefaults.standardUserDefaults()
        if let syncDate = defaults.stringForKey("syncdate") {
            self.lastSyncDate = dateFormatter.dateFromString(syncDate)
        }
        
        // Open app window
        self.onGalleryClick(self)
        
        // Check auth
        self.googleAuth = GTMOAuth2WindowController.authForGoogleFromKeychainForName(self.keychainToken, clientID: self.clientId, clientSecret: self.clientSecret)
        if (!self.googleAuth.canAuthorize) {
            self.loginMenuItem?.title = self.loginMenuTitle
        } else {
            self.loginMenuItem?.title = "Logout"
            self.appWC?.onUserLoggedIn()
        }
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
    }
    

    // ----- Menu actions ------//
    
    func onQuitClick(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(nil)
    }

    func onLoginClick(sender: AnyObject) {
        // Logging out?
        if self.loginMenuItem?.title != self.loginMenuTitle {
            GTMOAuth2WindowController.removeAuthFromKeychainForName(self.keychainToken)
            GTMOAuth2WindowController.revokeTokenForGoogleAuthentication(self.googleAuth)
            
            self.loginMenuItem?.title = self.loginMenuTitle
            
            self.appWC?.onUserLoggedOut()
            return
        }
        
        // Logging in
        self.loginWC = GTMOAuth2WindowController(scope: "https://www.googleapis.com/auth/gmail.readonly", clientID: self.clientId, clientSecret: self.clientSecret, keychainItemName: self.keychainToken, resourceBundle: NSBundle(forClass: GTMOAuth2WindowController.self))
        self.loginWC?.initialHTMLString = "Authentication for Mailage"
        self.loginWC?.signInSheetModalForWindow(nil, completionHandler: { (auth, err) in
            self.googleAuth = auth
            
            self.appWC?.onUserLoggedIn()
        })
        
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }
    
    func onGalleryClick(sender: AnyObject) {
        if ((self.appWC == nil)) {
            if let wc = NSStoryboard(name: "Main", bundle: NSBundle.mainBundle()).instantiateInitialController() as? AppWindowController {
                self.appWC = wc
                self.appWC?.window?.titleVisibility = .Hidden
            }
        }
        
        self.appWC?.showWindow(nil)
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }

}

