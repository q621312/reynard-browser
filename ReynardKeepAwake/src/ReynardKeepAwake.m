#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Reynard KeepAwake 1.0
// Target bundle: com.minh-ton.Reynard
// Keep the screen awake only while Reynard is active in the foreground.

static BOOL RKAEnforcing = NO;
static BOOL RKARequestedIdleTimerDisabled = NO;
static IMP RKAOriginalSetter = NULL;
static BOOL RKAHookInstalled = NO;

static void RKAInvokeOriginal(id obj, SEL selector, BOOL value) {
    if (RKAOriginalSetter) {
        ((void (*)(id, SEL, BOOL))RKAOriginalSetter)(obj, selector, value);
    }
}

static void RKAIdleTimerSetterHook(id self, SEL selector, BOOL requestedValue) {
    // Track the app's requested state; while foreground-active, force idle timer off.
    RKARequestedIdleTimerDisabled = requestedValue;
    RKAInvokeOriginal(self, selector, RKAEnforcing ? YES : requestedValue);
}

static void RKAInstallHook(void) {
    if (RKAHookInstalled) return;
    Method setterMethod = class_getInstanceMethod(UIApplication.class, @selector(setIdleTimerDisabled:));
    if (!setterMethod) return;
    RKAOriginalSetter = method_getImplementation(setterMethod);
    method_setImplementation(setterMethod, (IMP)RKAIdleTimerSetterHook);
    RKAHookInstalled = YES;
}

static void RKAEnableForActiveApp(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (!RKAEnforcing) {
        RKARequestedIdleTimerDisabled = app.idleTimerDisabled;
    }
    RKAEnforcing = YES;
    RKAInvokeOriginal(app, @selector(setIdleTimerDisabled:), YES);
}

static void RKARestoreAppRequest(void) {
    UIApplication *app = UIApplication.sharedApplication;
    RKAEnforcing = NO;
    RKAInvokeOriginal(app, @selector(setIdleTimerDisabled:), RKARequestedIdleTimerDisabled);
}

__attribute__((constructor)) static void ReynardKeepAwakeInit(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.minh-ton.Reynard"]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            RKAInstallHook();
            if (!RKAHookInstalled) return;

            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                RKAEnableForActiveApp();
            }];
            [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                RKARestoreAppRequest();
            }];
            [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                RKARestoreAppRequest();
            }];
            if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
                RKAEnableForActiveApp();
            }
        });
    }
}
