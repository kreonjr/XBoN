//
//  ViewController.swift
//  XbON
//
//  Created by Creon Creonopoulos on 3/2/17.
//  Copyright © 2017 Creon Creonopoulos. All rights reserved.
//

import UIKit
import Foundation
import SystemConfiguration.CaptiveNetwork
import MMLanScan

class ViewController: UIViewController, MMLANScannerDelegate {
    
    static let XBOX_IP_KEY = "XboxKey"
    static let LIVE_ID_KEY = "LiveID"
    static let SERVER_IP = "ServerIP"
    static let PORT = 3002
    static let USE_SERVER = true
    
    @IBOutlet weak var activityMonitor: UIActivityIndicatorView!
    var lanScanner : MMLANScanner!
    
    @IBOutlet weak var SSIDName: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityMonitor.hidesWhenStopped = true;
        self.activityMonitor.startAnimating()
        self.SSIDName.text = "Looking for XBOX device..."
        self.lanScanner = MMLANScanner(delegate:self)
        self.lanScanner.start()
    }
    
    func checkForInputData() {
        self.activityMonitor.startAnimating()
        
        if UserDefaults.standard.string(forKey: ViewController.SERVER_IP).isNilOrEmpty || 
           UserDefaults.standard.string(forKey: ViewController.LIVE_ID_KEY).isNilOrEmpty || 
           UserDefaults.standard.string(forKey: ViewController.XBOX_IP_KEY).isNilOrEmpty {
            presentServerAlert()
        }
        else {
            self.SSIDName.text = "Looking for server on network..."
            startSendingPowerOnMessage()
        }
    }
    
    func startSendingPowerOnMessage() {
        self.SSIDName.text = "Sending Signal..."
        
        var ipPathString:String = ""
        if let ipAddress = ViewController.getWiFiAddress() {
            let hostsArray = ipAddress.components(separatedBy: ".")
            if hostsArray.count > 3 {
                ipPathString = "\(hostsArray[0]).\(hostsArray[1]).\(hostsArray[2])."
            }
            else {
                return
            }
        }
        
        guard let XboxIPHost = UserDefaults.standard.string(forKey: ViewController.XBOX_IP_KEY), 
            let liveID = UserDefaults.standard.string(forKey: ViewController.LIVE_ID_KEY) else {
                self.SSIDName.text = "Failed creating URL"
                return
        }
        
        let XBOXIP = ipPathString + XboxIPHost
        
        if (ViewController.USE_SERVER) {
            sendOnSignalToServer(ipPathString: ipPathString, liveID: liveID, xboxIp:XBOXIP)
        }
        else {
            sendOnSignal(xboxIP:XBOXIP, liveID:liveID)
        }
    }
    
    func sendOnSignal(xboxIP:String, liveID:String) {
        let xboxManager = XBOXMessager()
        self.activityMonitor.stopAnimating()
        //self.SSIDName.text = xboxManager.powerOn(xboxIP: xboxIP, LiveID: liveID.uppercased())["message"]
        xboxManager.powerOn(xboxIP: xboxIP, LiveID: liveID.uppercased()) { (responseDict) in
            self.SSIDName.text = responseDict["message"]
        }
    }
    
    func sendOnSignalToServer(ipPathString:String, liveID:String, xboxIp:String) {
        guard let serverIP = UserDefaults.standard.string(forKey: ViewController.SERVER_IP),
              let serverAddressURL = URL(string:"http://" + ipPathString + serverIP + ":\(ViewController.PORT)/powerOn?XboxIP=\(xboxIp)&LiveID=\(liveID.uppercased())") else {
            self.SSIDName.text = "Failed creating URL"
            return
        }
        var urlRequest = URLRequest(url: serverAddressURL)
        urlRequest.httpMethod = "GET"
        let session = URLSession.shared    
        
        session.dataTask(with: urlRequest) { (data, response, error) in

            var responseString:String? = "There was an error with the response"
            
            if let data = data {
                let jsonDict = try! JSONSerialization.jsonObject(with: data, options: []) as? [String:Any]
                responseString = jsonDict?["message"] as? String
            }
            else if error != nil {
                responseString = error?.localizedDescription
            }
            
            DispatchQueue.main.async {
                self.SSIDName.text = responseString
                self.activityMonitor.stopAnimating()
            }
            
        }.resume()
    }
    
    @IBAction func presentServerAlert() {
        let alertView = UIAlertController(title: "Info Needed",
                                          message: "Please enter host ID info (last digits of ip) and Xbox device Live ID",
                                          preferredStyle: .alert)
        
        alertView.addTextField { (textField) in
            textField.text = UserDefaults.standard.string(forKey: ViewController.XBOX_IP_KEY)
            textField.placeholder = "XBOX HOST ID"
            textField.keyboardType = .numberPad
        }
        
        alertView.addTextField { (textField) in
            textField.text = UserDefaults.standard.string(forKey: ViewController.LIVE_ID_KEY)
            textField.placeholder = "XBOX LIVE DEVICE ID"
            textField.keyboardType = .namePhonePad
        }
        
        alertView.addTextField { (textField) in
            textField.text = UserDefaults.standard.string(forKey: ViewController.SERVER_IP)
            textField.placeholder = "SERVER HOST ID"
            textField.keyboardType = .namePhonePad
        }
        
        alertView.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak alertView] (_) in
            UserDefaults.standard.set(alertView?.textFields?[0].text, forKey: ViewController.XBOX_IP_KEY)
            UserDefaults.standard.set(alertView?.textFields?[1].text, forKey: ViewController.LIVE_ID_KEY)
            UserDefaults.standard.set(alertView?.textFields?[2].text, forKey: ViewController.SERVER_IP)
            self.checkForInputData()
        }))
        
        self.present(alertView, animated: true, completion: nil)
    }
    
    // Return IP address of WiFi interface (en0) as a String, or `nil`
    static func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    func lanScanDidFindNewDevice(_ device: MMDevice!) {
        //Most popular Microsoft device mac address pattern
        if let mac = device.macAddress, mac.contains("BC:83:85") {
            if let hostId = device.ipAddress.components(separatedBy: ".").last {
                UserDefaults.standard.set(hostId, forKey: ViewController.XBOX_IP_KEY)
                self.lanScanner.stop()
            }
        }
    }
    
    func lanScanDidFinishScanning(with status: MMLanScannerStatus) {
        checkForInputData()
    }
    
    func lanScanDidFailedToScan() {
        checkForInputData()
    }
}

extension ViewController: URLSessionDelegate {
    
}

protocol OptionalString {}
extension String: OptionalString {}

extension Optional where Wrapped: OptionalString {
    var isNilOrEmpty: Bool {
        return ((self as? String) ?? "").isEmpty
    }
}
