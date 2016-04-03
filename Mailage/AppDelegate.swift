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
    var googleAuth: GTMOAuth2Authentication! = nil
    
    var loginMenuItem: NSMenuItem?

    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    
    let keychainToken = "Mailage Mac"
    let clientId = "653085801125-tn3i386peicmjia3e7m1joe9jf0vclsd.apps.googleusercontent.com"
    let clientSecret = "0aZQX6Q1Yx35wksuHYwmmkkL"
    let loginMenuTitle = "Login"

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
            return
        }
        
        // Logging in
        if (self.loginWC == nil) {
            self.loginWC = GTMOAuth2WindowController(scope: "https://www.googleapis.com/auth/gmail.readonly", clientID: self.clientId, clientSecret: self.clientSecret, keychainItemName: self.keychainToken, resourceBundle: nil)
            self.loginWC?.initialHTMLString = "Authentication for Mailage"
        }
        self.loginWC?.signInSheetModalForWindow(nil, completionHandler: { (auth, err) in
            self.googleAuth = auth
            if (self.googleAuth.canAuthorize) {
                print("ready to go")
            } else {
                print("not authorized")
            }
        })
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }

    func onGalleryClick(sender: AnyObject) {
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

