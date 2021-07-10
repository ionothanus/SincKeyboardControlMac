// Derived from Swift-HID-Example/KuandoSwift, licensed as follows:
// The MIT License (MIT)
//
// Copyright (c) 2016 Eric Betts
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import Foundation
import IOKit.hid

struct JMStrings {
    static let REQUEST_SELECT_WINDOWS = "\u{02}JMLS0"; // xmit to kb: request layer 0 (Windows)
    static let REQUEST_SELECT_MAC = "\u{02}JMLS1"; // xmit to kb: request layer 1 (Mac)
    static let REQUEST_LAYER_STATUS = "\u{02}JMLR"; // xmit to kb: report current layer
    static let REQUEST_DISABLE_KEY = "\u{02}JMLD"; // xmit to kb: request disable switch macro key
    static let REQUEST_ENABLE_KEY = "\u{02}JMLE"; // xmit to kb: request disable switch macro key
    static let RESPONSE_WINDOWS = "\u{02}JML\u{0f}"; // recv from kb: response to request - Windows
    static let RESPONSE_MAC = "\u{02}JML\u{0e}"; // recv from kb: response to request - Mac selected
    static let RESPONSE_KEY_DISABLED = "\u{02}JMLDS"; // recv from kb: response to request - key disabled
    static let RESPONSE_KEY_ENABLED = "\u{02}JMLES"; // recv from kb: response to layer request - key enabled
    static let EVENT_LAYER_WINDOWS = "\u{02}JML0"; // recv from kb: user changed layer using keyboard - Windows
    static let EVENT_LAYER_MAC = "\u{02}JML1"; // recv from kb: user changed layer using keyboard - Mac
    static let SHORTEST_STRING = 4;
}
    
struct ParseError: Error {
    let message: String
    
    init(_ message: String)
    {
        self.message = message
    }
    
    public var errorDescription: String?
    {
        return message
    }
}
    
class SincHidController : NSObject {
    let vendorId = 0xCB10
    let productId = 0x1267
    let usage = 0x61
    let usagePage = 0xFF60
    let reportSize = 32 //Device specific
    static let singleton = SincHidController()
    var device : IOHIDDevice? = nil
    
    func processKeyboardMessage(_ message: String) {
        let messageTrimmed = message.trimmingCharacters(in: CharacterSet(charactersIn: "\u{0}"))
        switch (messageTrimmed)
        {
            case JMStrings.RESPONSE_MAC,
                 JMStrings.REQUEST_SELECT_MAC,
                 JMStrings.EVENT_LAYER_MAC:
                print("Mac layer selected")
            case JMStrings.RESPONSE_WINDOWS,
                 JMStrings.REQUEST_SELECT_WINDOWS,
                 JMStrings.EVENT_LAYER_WINDOWS:
                print ("Windows layer selected")
            case JMStrings.RESPONSE_KEY_ENABLED:
                print ("Layer select key disabled")
            case JMStrings.RESPONSE_KEY_DISABLED:
                print ("Layer select key enabled")
            default:
                print ("Unknown response")
                
        }
    }
    
    func input(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, type: IOHIDReportType, reportId: UInt32, report: UnsafeMutablePointer<UInt8>, reportLength: CFIndex) throws {
        let message = Data(bytes: report, count: reportLength)
        if let messageString = String(bytes: message, encoding: .utf8) {
            processKeyboardMessage(messageString)
        }
        else {
            throw ParseError("Can't convert response from keyboard to string")
        }
        
        print("Input received: \(message)")
    }
    
    func output(_ data: Data) {
        if (data.count > reportSize) {
            print("output data too large for USB report")
            return
        }
        let reportId : CFIndex = CFIndex(data[0])
        if let blink1 = device {
            print("Sending output: \([UInt8](data))")
            IOHIDDeviceSetReport(blink1, kIOHIDReportTypeFeature, reportId, [UInt8](data), data.count)
        }
    }
    
    func connected(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
        print("Device connected")
        // It would be better to look up the report size and create a chunk of memory of that size
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)        
        device = inIOHIDDeviceRef
        
        let inputCallback : IOHIDReportCallback = { inContext, inResult, inSender, type, reportId, report, reportLength in
            let this : SincHidController = Unmanaged<SincHidController>.fromOpaque(inContext!).takeUnretainedValue()
            try? this.input(inResult, inSender: inSender!, type: type, reportId: reportId, report: report, reportLength: reportLength)
        }
        
        //Hook up inputcallback
        let this = Unmanaged.passRetained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device!, report, reportSize, inputCallback, this)
        
        /* https://github.com/todbot/blink1/blob/master/docs/blink1-hid-commands.md
         - byte 0 = report_id (0x01)
         - byte 1 = command action ('c' = fade to rgb, 'v' get firmware version, etc.)
         - byte 2 = cmd arg 0 (e.g. red)
         - byte 3 = cmd arg 1 (e.g. green)
         - byte 4 = cmd arg 2 (e.g. blue)
         */
        
        //Turn on light to demonstrate sending a command
        /*let reportId : UInt8 = 1
        let command : UInt8 = UInt8(ascii: "n")
        let r : UInt8 = 0
        let g : UInt8 = 0xFF
        let b : UInt8 = 0
        let bytes : [UInt8] = [reportId, command, r, g, b]
        
        self.output(Data(bytes))*/
    }
    
    func removed(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
        print("Device removed")
        NotificationCenter.default.post(name: Notification.Name(rawValue: "deviceDisconnected"), object: nil, userInfo: ["class": NSStringFromClass(type(of: self))])
    }
    

    @objc func initUsb() {
        let deviceMatch = [kIOHIDProductIDKey: productId, kIOHIDVendorIDKey: vendorId, kIOHIDPrimaryUsagePageKey: usagePage, kIOHIDPrimaryUsageKey: usage]
        let managerRef = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        IOHIDManagerSetDeviceMatching(managerRef, deviceMatch as CFDictionary?)
        IOHIDManagerScheduleWithRunLoop(managerRef, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(managerRef, 0)
        
        let matchingCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
            let this : SincHidController = Unmanaged<SincHidController>.fromOpaque(inContext!).takeUnretainedValue()
            this.connected(inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
        }
        
        let removalCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
            let this : SincHidController = Unmanaged<SincHidController>.fromOpaque(inContext!).takeUnretainedValue()
            this.removed(inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
        }
        
        let this = Unmanaged.passRetained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(managerRef, matchingCallback, this)
        IOHIDManagerRegisterDeviceRemovalCallback(managerRef, removalCallback, this)
        
        RunLoop.current.run()
    }

}
