//
//  LoginWindowController.swift
//  Mailage
//
//  Created by Musawir Shah on 4/1/16.
//  Copyright © 2016 YourMechanic. All rights reserved.
//

import Foundation
import Cocoa
import WebKit

class LoginWindowController: NSWindowController {
    @IBOutlet weak var loginWebView: WebView!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.loginWebView.mainFrame.loadRequest(NSURLRequest(URL: NSURL(string: "https://accounts.google.com/o/oauth2/token")!))
        //self.loginWebView.mainFrame.loadHTMLString("hi", baseURL: NSURL())
    }
}