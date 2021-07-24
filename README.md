# SincKeyboardControlMac

This is a proof-of-concept Mac application to interact with some custom QMK functions on my Sinc keyboard using raw HID reports. It is written in Swift and uses IOKit to interact with the keyboard.

I made this because I use my keyboard with both Windows and Mac systems. I want the left modifier keys to be in the "correct" (idiomatic for the platform) order on the platform I'm currently using. I had configured layer 0 as the default/Windows order, and added layer 1 to rearrange the modifier keys for Mac, with one of the macro keys configured to toggle layer 1 on and off. 

However, I kept hitting the layer-toggle key. And I realized I don't really need that key other than one time at startup. It would be way better if my computers just set the correct configuration when the keyboard was connected, and disabled the key. So I wrote this, and [its companion Windows application](https://github.com/ionothanus/SincKeyboardControl), to accomplish that.

## Assumptions

This codebase assumes:
- your keyboard is running [QMK firmware with an implementation](https://github.com/ionothanus/qmk_firmware/blob/master/keyboards/keebio/sinc/keymaps/via_custom/keymap.c) which responds to the raw HID reports this application sends, and sends its own events on layer changes
- layer 0 is configured as your "Windows" layer
- layer 1 is configured as your "Mac" layer

You can, of course, make any modifications to this or your keyboard firmware to do whatever you want. This is just what works for me.

## Usage

1. Run this application.
2. Connect a keyboard running the QMK firmware you modified to implement the keyboard end of things.

The application will then disable the `TG(1)` keycode (i.e., it will intercept it in the keyboard firmware and replace it with a no-op), and ensure that layer 1 is disabled. You can control all of this behaviour by right-clicking on the menu bar icon.

Assuming everything is in place firmware-wise, the menu bar icon will change to indicate which state is active:
- a Command symbol in an empty square (denoting "inactive") for the Windows/layer 0 mode
- a Command symbol in a filled square (denoting "active") for the Mac/layer 1 mode
- an Option symbol when the keyboard is disconnected

So long as the application exits normally, the `TG(1)` keycode will be automatically re-enabled on exit. This will also be re-enabled by disconnecting and reconnecting the keyboard, assuming your firmware is implemented appropriately for that to happen.

## Building

You should be able to open the project in XCode to build it yourself. I don't really know what that will involve because I don't have a lot of experience sharing XCode projects. If this doesn't work, please open an issue to let me know.

## License

This application is provided under the [MIT license](https://github.com/ionothanus/SincKeyboardControlMac/blob/main/LICENSE.md).