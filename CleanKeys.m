#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <IOKit/hidsystem/ev_keymap.h>

extern int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);
extern int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness);

static id gKeyboardClient = nil;
static CFMachPortRef gEventTap = NULL;

#pragma mark - Hardware Audio & Display Controls

static BOOL setDeviceVolumeOnElement(AudioDeviceID deviceID, UInt32 element, float delta) {
    AudioObjectPropertyAddress volAddr = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        element
    };
    if (!AudioObjectHasProperty(deviceID, &volAddr)) return NO;

    Boolean isSettable = false;
    if (AudioObjectIsPropertySettable(deviceID, &volAddr, &isSettable) != noErr || !isSettable) {
        return NO;
    }

    Float32 vol = 0;
    UInt32 size = sizeof(vol);
    if (AudioObjectGetPropertyData(deviceID, &volAddr, 0, NULL, &size, &vol) != noErr) {
        return NO;
    }

    vol += delta;
    if (vol < 0.0f) vol = 0.0f;
    if (vol > 1.0f) vol = 1.0f;
    return (AudioObjectSetPropertyData(deviceID, &volAddr, 0, NULL, sizeof(vol), &vol) == noErr);
}

BOOL adjustVolume(float delta) {
    // 1. Direct CoreAudio HAL control
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioDeviceID deviceID = kAudioObjectUnknown;
    UInt32 size = sizeof(deviceID);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceID) == noErr && deviceID != kAudioObjectUnknown) {
        // Try master channel (0) first
        if (setDeviceVolumeOnElement(deviceID, kAudioObjectPropertyElementMain, delta)) {
            return YES;
        }

        // Fall back to discrete stereo channels (1 & 2)
        // Essential for AirPods, Bluetooth headphones, external USB DACs & monitors
        BOOL ch1 = setDeviceVolumeOnElement(deviceID, 1, delta);
        BOOL ch2 = setDeviceVolumeOnElement(deviceID, 2, delta);
        if (ch1 || ch2) {
            return YES;
        }
    }

    // 2. High-level AppleScript fallback (bypasses HUD and talks directly to macOS sound server)
    NSAppleScript *asGet = [[NSAppleScript alloc] initWithSource:@"output volume of (get volume settings)"];
    NSAppleEventDescriptor *res = [asGet executeAndReturnError:nil];
    if (res) {
        int currentVol = (int)[res int32Value];
        int change = (int)roundf(delta * 100.0f);
        if (change == 0) change = (delta > 0) ? 1 : -1;
        int newVol = currentVol + change;
        if (newVol < 0) newVol = 0;
        if (newVol > 100) newVol = 100;

        NSString *setSrc = [NSString stringWithFormat:@"set volume output volume %d", newVol];
        NSAppleScript *asSet = [[NSAppleScript alloc] initWithSource:setSrc];
        return ([asSet executeAndReturnError:nil] != nil);
    }

    return NO;
}

static BOOL setDeviceMuteOnElement(AudioDeviceID deviceID, UInt32 element) {
    AudioObjectPropertyAddress muteAddr = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeOutput,
        element
    };
    if (!AudioObjectHasProperty(deviceID, &muteAddr)) return NO;

    Boolean isSettable = false;
    if (AudioObjectIsPropertySettable(deviceID, &muteAddr, &isSettable) != noErr || !isSettable) {
        return NO;
    }

    UInt32 mute = 0;
    UInt32 size = sizeof(mute);
    if (AudioObjectGetPropertyData(deviceID, &muteAddr, 0, NULL, &size, &mute) != noErr) {
        return NO;
    }

    mute = !mute;
    return (AudioObjectSetPropertyData(deviceID, &muteAddr, 0, NULL, sizeof(mute), &mute) == noErr);
}

BOOL toggleMute(void) {
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioDeviceID deviceID = kAudioObjectUnknown;
    UInt32 size = sizeof(deviceID);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceID) == noErr && deviceID != kAudioObjectUnknown) {
        if (setDeviceMuteOnElement(deviceID, kAudioObjectPropertyElementMain)) {
            return YES;
        }
        BOOL ch1 = setDeviceMuteOnElement(deviceID, 1);
        BOOL ch2 = setDeviceMuteOnElement(deviceID, 2);
        if (ch1 || ch2) return YES;
    }

    // High-level AppleScript fallback
    NSAppleScript *asGet = [[NSAppleScript alloc] initWithSource:@"output muted of (get volume settings)"];
    NSAppleEventDescriptor *res = [asGet executeAndReturnError:nil];
    if (res) {
        BOOL isMuted = (BOOL)[res booleanValue];
        NSString *setSrc = [NSString stringWithFormat:@"set volume output muted %s", isMuted ? "false" : "true"];
        NSAppleScript *asSet = [[NSAppleScript alloc] initWithSource:setSrc];
        return ([asSet executeAndReturnError:nil] != nil);
    }
    return NO;
}

BOOL adjustDisplayBrightness(float delta) {
    CGDirectDisplayID mainDisplay = CGMainDisplayID();
    float brightness = 0.0f;
    if (DisplayServicesGetBrightness(mainDisplay, &brightness) != 0) return NO;
    brightness += delta;
    if (brightness < 0.0f) brightness = 0.0f;
    if (brightness > 1.0f) brightness = 1.0f;
    return (DisplayServicesSetBrightness(mainDisplay, brightness) == 0);
}

BOOL adjustKeyboardBrightness(float delta) {
    if (!gKeyboardClient) {
        [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/CoreBrightness.framework"] load];
        gKeyboardClient = [[NSClassFromString(@"KeyboardBrightnessClient") alloc] init];
    }
    if (!gKeyboardClient) return NO;

    SEL selGet = @selector(brightnessForKeyboard:);
    SEL selSet = @selector(setBrightness:forKeyboard:);
    SEL selSetAuto = @selector(enableAutoBrightness:forKeyboard:);
    if (![gKeyboardClient respondsToSelector:selGet] || ![gKeyboardClient respondsToSelector:selSet]) return NO;

    if ([gKeyboardClient respondsToSelector:selSetAuto]) {
        ((BOOL (*)(id, SEL, BOOL, unsigned long))[gKeyboardClient methodForSelector:selSetAuto])(gKeyboardClient, selSetAuto, NO, 1);
    }

    float current = ((float (*)(id, SEL, unsigned long))[gKeyboardClient methodForSelector:selGet])(gKeyboardClient, selGet, 1);
    float next = current + delta;
    if (next < 0.0f) next = 0.0f;
    if (next > 1.0f) next = 1.0f;
    ((void (*)(id, SEL, float, unsigned long))[gKeyboardClient methodForSelector:selSet])(gKeyboardClient, selSet, next, 1);
    return YES;
}

#pragma mark - Event Tap Callback

CGEventRef cleanKeysEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (gEventTap) CGEventTapEnable(gEventTap, true);
        return event;
    }

    if (type == (CGEventType)14) { // NX_SYSDEFINED
        NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];
        if (nsEvent.subtype == 8) { // NX_SUBTYPE_AUX_CONTROL_BUTTONS
            NSInteger data1 = [nsEvent data1];
            int keyCode = (data1 & 0xFFFF0000) >> 16;
            int keyFlags = data1 & 0x0000FFFF;
            int keyState = (keyFlags & 0xFF00) >> 8;
            BOOL isKeyDown = (keyState == 0x0A || keyState == 0x01);

            // Shift + Option fine step (1/4 tick = 1/64th step)
            BOOL fineStep = ((nsEvent.modifierFlags & (NSEventModifierFlagShift | NSEventModifierFlagOption)) == (NSEventModifierFlagShift | NSEventModifierFlagOption));
            float volDelta = fineStep ? 0.015625f : 0.0625f;
            float brightDelta = fineStep ? 0.015625f : 0.0625f;
            float keybDelta = fineStep ? 0.025f : 0.10f;

            if (isKeyDown) {
                switch (keyCode) {
                    case NX_KEYTYPE_SOUND_UP:
                        if (adjustVolume(volDelta)) return NULL;
                        return event;
                    case NX_KEYTYPE_SOUND_DOWN:
                        if (adjustVolume(-volDelta)) return NULL;
                        return event;
                    case NX_KEYTYPE_MUTE:
                        if (toggleMute()) return NULL;
                        return event;
                    case NX_KEYTYPE_BRIGHTNESS_UP:
                        if (adjustDisplayBrightness(brightDelta)) return NULL;
                        return event;
                    case NX_KEYTYPE_BRIGHTNESS_DOWN:
                        if (adjustDisplayBrightness(-brightDelta)) return NULL;
                        return event;
                    case NX_KEYTYPE_ILLUMINATION_UP:
                        if (adjustKeyboardBrightness(keybDelta)) return NULL;
                        return event;
                    case NX_KEYTYPE_ILLUMINATION_DOWN:
                        if (adjustKeyboardBrightness(-keybDelta)) return NULL;
                        return event;
                    default:
                        break;
                }
            } else if (keyState == 0x0B) { // Key release
                switch (keyCode) {
                    case NX_KEYTYPE_SOUND_UP:
                    case NX_KEYTYPE_SOUND_DOWN:
                    case NX_KEYTYPE_MUTE:
                    case NX_KEYTYPE_BRIGHTNESS_UP:
                    case NX_KEYTYPE_BRIGHTNESS_DOWN:
                    case NX_KEYTYPE_ILLUMINATION_UP:
                    case NX_KEYTYPE_ILLUMINATION_DOWN:
                        return NULL;
                    default:
                        break;
                }
            }
        }
    }
    return event;
}

#pragma mark - Application Delegate (Completely Headless & Non-Invasive)

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) NSTimer *permissionTimer;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // 1. Single Instance Check: If already running, offer a frictionless Quit dialog
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleId) bundleId = @"com.amarinspire.cleankeys";

    NSArray<NSRunningApplication *> *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleId];
    pid_t myPid = [[NSProcessInfo processInfo] processIdentifier];

    NSRunningApplication *existingInstance = nil;
    for (NSRunningApplication *app in instances) {
        if (app.processIdentifier != myPid) {
            existingInstance = app;
            break;
        }
    }

    if (existingInstance) {
        // App is already running in the background!
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"CleanKeys is Active";
        alert.informativeText = @"CleanKeys is running silently in the background with zero menu bar clutter, keeping your screen clean.\n\nWould you like to keep it running or quit?";
        [alert addButtonWithTitle:@"Keep Running"];
        [alert addButtonWithTitle:@"Quit CleanKeys"];
        alert.alertStyle = NSAlertStyleInformational;

        [NSApp activateIgnoringOtherApps:YES];
        if ([alert runModal] == NSAlertSecondButtonReturn) {
            [existingInstance terminate];
            [self sendNotificationWithTitle:@"CleanKeys Stopped" message:@"CleanKeys has been quit. Normal macOS popups restored."];
        }
        [NSApp terminate:nil];
        return;
    }

    // 2. Start Headless Event Interceptor
    [self ensureAutoStart];
    [self checkAccessibilityPermissions];
}

- (void)checkAccessibilityPermissions {
    if (AXIsProcessTrusted()) {
        [self startEventTap];
    } else {
        // Continuous background polling so when the user toggles it in Settings, it starts immediately
        self.permissionTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            if (AXIsProcessTrusted()) {
                [timer invalidate];
                self.permissionTimer = nil;
                [self startEventTap];
            }
        }];
    }
}

- (void)startEventTap {
    if (gEventTap) return;

    CGEventMask mask = CGEventMaskBit(14); // NX_SYSDEFINED
    gEventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        mask,
        cleanKeysEventCallback,
        NULL
    );

    if (gEventTap) {
        CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gEventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
        CGEventTapEnable(gEventTap, true);
        CFRelease(source);
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startEventTap];
        });
    }
}

- (void)sendNotificationWithTitle:(NSString *)title message:(NSString *)msg {
    NSString *script = [NSString stringWithFormat:@"display notification \"%@\" with title \"%@\"", msg, title];
    NSAppleScript *as = [[NSAppleScript alloc] initWithSource:script];
    [as executeAndReturnError:nil];
}

- (void)ensureAutoStart {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if (![defs boolForKey:@"hasConfiguredAutoStart"]) {
        [defs setBool:YES forKey:@"hasConfiguredAutoStart"];
        NSString *appPath = [[NSBundle mainBundle] bundlePath];
        if (appPath && [appPath hasPrefix:@"/Applications"]) {
            NSString *script = [NSString stringWithFormat:
                @"tell application \"System Events\"\n"
                @"  if not (exists (login item \"CleanKeys\")) then\n"
                @"    make login item at end with properties {path:\"%@\", hidden:false}\n"
                @"  end if\n"
                @"end tell", appPath];
            NSAppleScript *as = [[NSAppleScript alloc] initWithSource:script];
            [as executeAndReturnError:nil];
        }
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
