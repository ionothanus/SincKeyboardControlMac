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

enum KeyboardLayers {
    case Windows
    case Mac
}

enum KeyboardEventType {
    case LayerChange
    case KeyEnableChange
    case ConnectionChange
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
    typealias KeyboardEventCallback =
        (_ eventType: KeyboardEventType) -> Void
    
    let vendorId = 0xCB10
    let productId = 0x1267
    let usage = 0x61
    let usagePage = 0xFF60
    var device : IOHIDDevice? = nil
    var reportSize : Int = -1
    
    var currentLayer : KeyboardLayers? = nil
    var isConnected = false
    var layerKeyEnabled : Bool? = nil
    
    let updateCallback: KeyboardEventCallback?
    
    init(_ updateCallback: @escaping KeyboardEventCallback) {
        self.updateCallback = updateCallback
    }
    
    func disableLayerKey() {
        output(JMStrings.REQUEST_DISABLE_KEY)
    }
    
    func enableLayerKey() {
        output(JMStrings.REQUEST_ENABLE_KEY)
    }
    
    func selectLayer(_ layer: KeyboardLayers) {
        output(layer == KeyboardLayers.Windows ? JMStrings.REQUEST_SELECT_WINDOWS :
                JMStrings.REQUEST_SELECT_MAC)
    }
    
    func refreshLayerState() {
        output(JMStrings.REQUEST_LAYER_STATUS)
    }
    
    func processKeyboardMessage(_ message: String) {
        let messageTrimmed = message.trimmingCharacters(in: CharacterSet(charactersIn: "\u{0}"))
        switch (messageTrimmed)
        {
            case JMStrings.RESPONSE_MAC,
                 JMStrings.REQUEST_SELECT_MAC,
                 JMStrings.EVENT_LAYER_MAC:
                print("Mac layer selected")
                currentLayer = KeyboardLayers.Mac
                updateCallback?(KeyboardEventType.LayerChange)
            case JMStrings.RESPONSE_WINDOWS,
                 JMStrings.REQUEST_SELECT_WINDOWS,
                 JMStrings.EVENT_LAYER_WINDOWS:
                print ("Windows layer selected")
                currentLayer = KeyboardLayers.Windows
                updateCallback?(KeyboardEventType.LayerChange)
            case JMStrings.RESPONSE_KEY_ENABLED:
                print ("Layer select key enabled")
                layerKeyEnabled = true
                updateCallback?(KeyboardEventType.KeyEnableChange)
            case JMStrings.RESPONSE_KEY_DISABLED:
                print ("Layer select key disabled")
                layerKeyEnabled = false
                updateCallback?(KeyboardEventType.KeyEnableChange)
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
    
    func output(_ string: String) {
        var bytes = Data(count: reportSize)
        let stringData = Data(string.utf8)
        bytes.replaceSubrange(0..<stringData.count + 0, with: stringData)
        
        output(bytes)
    }
    
    func output(_ data: Data) {
        if (data.count > reportSize) {
            print("output data too large for USB report")
            return
        }
        let reportId : CFIndex = 0//CFIndex = CFIndex(data[0])
        if let sincHid = device {
            print("Sending output: \([UInt8](data))")

            let result = IOHIDDeviceSetReport(sincHid, kIOHIDReportTypeOutput, reportId, [UInt8](data), data.count)
            print(result)
        }
    }
    
    func connected(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
        print("Device connected")
        // It would be better to look up the report size and create a chunk of memory of that size
        
        device = inIOHIDDeviceRef
        self.reportSize = IOHIDDeviceGetProperty(self.device!, kIOHIDMaxInputReportSizeKey as CFString) as! Int
        let report = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
        
        let inputCallback : IOHIDReportCallback = { inContext, inResult, inSender, type, reportId, report, reportLength in
            let this : SincHidController = Unmanaged<SincHidController>.fromOpaque(inContext!).takeUnretainedValue()
            try? this.input(inResult, inSender: inSender!, type: type, reportId: reportId, report: report, reportLength: reportLength)
        }
        
        //Hook up inputcallback
        let this = Unmanaged.passRetained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device!, report, reportSize, inputCallback, this)
        
        isConnected = true
        updateCallback?(KeyboardEventType.ConnectionChange)
        selectLayer(KeyboardLayers.Mac)
        disableLayerKey()
    }
    
    func removed(_ inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
        print("Device removed")
        isConnected = false
        updateCallback?(KeyboardEventType.ConnectionChange)
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
