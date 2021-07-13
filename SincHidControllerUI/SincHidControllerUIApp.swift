//
//  SincHidControllerUIApp.swift
//  SincHidControllerUI
//
//  Created by Jonathan Moscardini on 2021-07-09.
//

import SwiftUI

@main
struct SincHidControllerUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

struct MenuItems {
    let toggleLayerKey: NSMenuItem
    let layerSubMenuItem: NSMenuItem
    let layerSubMenu: NSMenu
    let layerMacOption: NSMenuItem
    let layerWindowsOption: NSMenuItem
    let refreshState: NSMenuItem
    let disconnectedStatus: NSMenuItem
    
    init() {
        toggleLayerKey = NSMenuItem(title: "Disable layer key", action: nil,
                                    keyEquivalent: "")
        
        layerMacOption = NSMenuItem(title: "Mac", action: nil, keyEquivalent: "")
        layerWindowsOption = NSMenuItem(title: "Windows", action: nil, keyEquivalent: "")
        
        layerSubMenu = NSMenu()
        layerSubMenu.addItem(layerMacOption)
        layerSubMenu.addItem(layerWindowsOption)
        
        layerSubMenuItem = NSMenuItem(title: "Select layer", action: nil, keyEquivalent: "")
        
        refreshState = NSMenuItem(title: "Refresh state", action: nil, keyEquivalent: "")
        
        disconnectedStatus = NSMenuItem(title: "Disconnected", action: nil, keyEquivalent: "")
        
        // assuming disconnected at startup - these will be corrected
        // on connection below.
        disconnectedStatus.isHidden = false
        layerSubMenuItem.isEnabled = false
        toggleLayerKey.isHidden = true
        refreshState.isHidden = true
    }
}

struct Icons {
    static let macLayerIcon = NSImage(systemSymbolName: "command.square.fill", accessibilityDescription: "Mac keyboard layer selected")
    static let windowsLayerIcon = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Windows keyboard layer selected")
    static let disconnectedIcon = NSImage(systemSymbolName: "option", accessibilityDescription: "Keyboard disconnected")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem? = nil
    var menuItems = MenuItems()
    var sincHid: SincHidController? = nil
    var daemon: Thread? = nil
    
    override init() {
        super.init()
        sincHid = SincHidController(handleKeyboardUpdates)
        daemon = Thread(target: sincHid!, selector:#selector(SincHidController.initUsb), object: nil)
    }
    
    func handleKeyboardUpdates(_ changeType: KeyboardEventType) {
        switch (changeType) {
            case KeyboardEventType.LayerChange:
                if let layer = sincHid?.currentLayer {
                    if layer == KeyboardLayers.Mac {
                        DispatchQueue.main.async {
                            self.statusBarItem?.button?.image = Icons.macLayerIcon
                        }
                    }
                    else if layer == KeyboardLayers.Windows {
                        DispatchQueue.main.async {
                            self.statusBarItem?.button?.image = Icons.windowsLayerIcon
                        }
                    }
                }
            case KeyboardEventType.KeyEnableChange:
                if let enabled = sincHid?.layerKeyEnabled {
                    if (enabled) {
                        DispatchQueue.main.async {
                            self.menuItems.toggleLayerKey.state = NSControl.StateValue.off
                            self.statusBarItem?.menu?.update()
                        }
                    }
                    else {
                        DispatchQueue.main.async {
                            self.menuItems.toggleLayerKey.state = NSControl.StateValue.on
                            self.statusBarItem?.menu?.update()
                        }
                    }
                }
            case KeyboardEventType.ConnectionChange:
                if let connected = sincHid?.isConnected {
                    if (!connected) {
                        DispatchQueue.main.async {
                            self.statusBarItem?.button?.image = Icons.disconnectedIcon
                            self.menuItems.disconnectedStatus.isHidden = false
                            self.menuItems.layerSubMenuItem.isEnabled = false
                            self.menuItems.toggleLayerKey.isHidden = true
                            self.menuItems.refreshState.isHidden = true
                            self.statusBarItem?.menu?.update()
                        }
                    }
                    else {
                        DispatchQueue.main.async {
                            self.menuItems.disconnectedStatus.isHidden = true
                            self.menuItems.layerSubMenuItem.isEnabled = true
                            self.menuItems.toggleLayerKey.isHidden = false
                            self.menuItems.refreshState.isHidden = false
                            self.statusBarItem?.menu?.update()
                        }
                    }
                }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        sincHid!.enableLayerKey()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        daemon!.start()

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem?.button {
            button.image = Icons.disconnectedIcon
        }
        constructMenu()
    }
    
    func constructMenu() {
        let menu = NSMenu()

        menuItems.refreshState.action = #selector(refreshState)
        menuItems.layerMacOption.action = #selector(setMacLayer)
        menuItems.layerWindowsOption.action = #selector(setWindowsLayer)
        menuItems.toggleLayerKey.action = #selector(toggleLayerKey)
        
        menuItems.layerSubMenu.update()

        menu.addItem(menuItems.toggleLayerKey)
        menu.addItem(menuItems.layerSubMenuItem)
        menu.setSubmenu(menuItems.layerSubMenu, for: menuItems.layerSubMenuItem)
        menu.addItem(menuItems.refreshState)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItems.disconnectedStatus)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusBarItem?.menu = menu
    }
    
    @objc func refreshState(_ sender: AnyObject?) {
        sincHid!.refreshLayerState()
    }
    
    @objc func setMacLayer(_ sender: AnyObject?) {
        sincHid!.selectLayer(KeyboardLayers.Mac)
    }
    
    @objc func setWindowsLayer(_ sender: AnyObject?) {
        sincHid!.selectLayer(KeyboardLayers.Windows)
    }
    
    @objc func toggleLayerKey(_ sender: AnyObject?) {
        if let layerKeyEnabled = sincHid!.layerKeyEnabled {
            if (layerKeyEnabled) {
                sincHid!.disableLayerKey()
            }
            else {
                sincHid!.enableLayerKey()
            }
        }
    }
}
