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
class AppDelegate: NSObject, NSApplicationDelegate, WebFrameLoadDelegate {

    @IBOutlet weak var window: NSWindow!
    var loginWC: GTMOAuth2WindowController?
    var googleAuth: GTMOAuth2Authentication! = nil

    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    
    let keychainToken = "Mailage Mac"
    let clientId = "653085801125-tn3i386peicmjia3e7m1joe9jf0vclsd.apps.googleusercontent.com"
    let clientSecret = "0aZQX6Q1Yx35wksuHYwmmkkL"

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Create menu
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
        }
        
        var objects: NSArray?
        NSBundle.mainBundle().loadNibNamed("StatusMenu", owner: nil, topLevelObjects: &objects)
        if let objects = objects {
            for object in objects {
                if let menu = object as? NSMenu {
                    statusItem.menu = menu
                    break
                }
            }
        }
        
        self.googleAuth = GTMOAuth2WindowController.authForGoogleFromKeychainForName(self.keychainToken, clientID: self.clientId, clientSecret: self.clientSecret)
        if (!self.googleAuth.canAuthorize) {
            // Need login
            print("Need login")
        } else {
            print("Logged in")
        }
    }

    @IBAction func onQuitClick(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(nil)
    }

    @IBAction func onLoginClick(sender: AnyObject) {
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
    
    func webView(sender: WebView!, didFinishLoadForFrame frame: WebFrame!) {
        print("finished loading")
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

