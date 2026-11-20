#import <Cocoa/Cocoa.h>

CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        CGEventTapEnable(*(CFMachPortRef *)refcon, true);
        return event;
    }
    NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];
    if (nsEvent && nsEvent.subtype == 8) {
        NSInteger keyCode = (nsEvent.data1 & 0xFFFF0000) >> 16;
        NSInteger keyFlags = nsEvent.data1 & 0x0000FFFF;
        NSInteger keyState = (keyFlags & 0xFF00) >> 8;
        // NX_POWER_KEY = 6, keyState == 0x0A (Key Down)
        if (keyCode == 6 && keyState == 0x0A) {
            system("osascript -e 'tell application \"System Events\" to shut down'");
            return NULL;
        }
    }
    return event;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CGEventMask mask = (1 << 14); // NX_SYSDEFINED
        CFMachPortRef tap = NULL;
        tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventCallback, &tap);
        if (!tap) {
            NSLog(@"Accessibility permission required for /usr/local/bin/PowerOff");
            return 1;
        }
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(tap, true);
        [[NSApplication sharedApplication] run];
    }
    return 0;
}
