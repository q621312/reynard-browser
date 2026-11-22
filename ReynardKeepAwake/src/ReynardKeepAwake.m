#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Reynard KeepAwake 2.0
// Adds a persistent switch to Reynard's Settings screen and keeps the
// screen awake only while the main app is active and the preference is on.

static NSString * const RKAEnabledKey = @"com.q621312.ReynardKeepAwake.enabled";

static BOOL RKAEnforcing = NO;
static BOOL RKARequestedIdleTimerDisabled = NO;
static IMP RKAOriginalSetter = NULL;
static BOOL RKAHookInstalled = NO;

static IMP RKAOriginalNumberOfSections = NULL;
static IMP RKAOriginalNumberOfRows = NULL;
static IMP RKAOriginalHeaderTitle = NULL;
static IMP RKAOriginalCellForRow = NULL;

static BOOL RKAIsEnabled(void) {
    id storedValue = [NSUserDefaults.standardUserDefaults objectForKey:RKAEnabledKey];
    return storedValue == nil ? YES : [NSUserDefaults.standardUserDefaults boolForKey:RKAEnabledKey];
}

static void RKAInvokeOriginal(id obj, SEL selector, BOOL value) {
    if (RKAOriginalSetter) {
        ((void (*)(id, SEL, BOOL))RKAOriginalSetter)(obj, selector, value);
    }
}

static void RKAIdleTimerSetterHook(id self, SEL selector, BOOL requestedValue) {
    RKARequestedIdleTimerDisabled = requestedValue;
    RKAInvokeOriginal(self, selector, RKAEnforcing ? YES : requestedValue);
}

static void RKAInstallIdleTimerHook(void) {
    if (RKAHookInstalled) return;
    Method setterMethod = class_getInstanceMethod(UIApplication.class, @selector(setIdleTimerDisabled:));
    if (!setterMethod) return;

    RKARequestedIdleTimerDisabled = UIApplication.sharedApplication.idleTimerDisabled;
    RKAOriginalSetter = method_getImplementation(setterMethod);
    method_setImplementation(setterMethod, (IMP)RKAIdleTimerSetterHook);
    RKAHookInstalled = YES;
}

static void RKAEnableForActiveApp(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (!RKAIsEnabled()) return;

    if (!RKAEnforcing) {
        RKARequestedIdleTimerDisabled = app.idleTimerDisabled;
    }
    RKAEnforcing = YES;
    RKAInvokeOriginal(app, @selector(setIdleTimerDisabled:), YES);
}

static void RKARestoreAppRequest(void) {
    if (!RKAEnforcing) return;
    UIApplication *app = UIApplication.sharedApplication;
    RKAEnforcing = NO;
    RKAInvokeOriginal(app, @selector(setIdleTimerDisabled:), RKARequestedIdleTimerDisabled);
}

static void RKAApplyCurrentPreference(void) {
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive && RKAIsEnabled()) {
        RKAEnableForActiveApp();
    } else {
        RKARestoreAppRequest();
    }
}

@interface RKASettingsSwitchTarget : NSObject
+ (instancetype)sharedTarget;
- (void)valueChanged:(UISwitch *)sender;
@end

@implementation RKASettingsSwitchTarget
+ (instancetype)sharedTarget {
    static RKASettingsSwitchTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [[self alloc] init];
    });
    return target;
}

- (void)valueChanged:(UISwitch *)sender {
    [NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:RKAEnabledKey];
    RKAApplyCurrentPreference();
}
@end

static NSInteger RKAOriginalSectionCount(id self, UITableView *tableView) {
    if (!RKAOriginalNumberOfSections) return 0;
    return ((NSInteger (*)(id, SEL, UITableView *))RKAOriginalNumberOfSections)(
        self, @selector(numberOfSectionsInTableView:), tableView
    );
}

static NSInteger RKASettingsNumberOfSections(id self, SEL selector, UITableView *tableView) {
    NSInteger originalCount = RKAOriginalSectionCount(self, tableView);
    return originalCount + 1;
}

static NSInteger RKASettingsNumberOfRows(id self, SEL selector, UITableView *tableView, NSInteger section) {
    NSInteger originalCount = RKAOriginalSectionCount(self, tableView);
    if (section == originalCount) return 1;
    return ((NSInteger (*)(id, SEL, UITableView *, NSInteger))RKAOriginalNumberOfRows)(
        self, @selector(tableView:numberOfRowsInSection:), tableView, section
    );
}

static NSString *RKASettingsHeaderTitle(id self, SEL selector, UITableView *tableView, NSInteger section) {
    NSInteger originalCount = RKAOriginalSectionCount(self, tableView);
    if (section == originalCount) return @"屏幕常亮";
    return ((id (*)(id, SEL, UITableView *, NSInteger))RKAOriginalHeaderTitle)(
        self, @selector(tableView:titleForHeaderInSection:), tableView, section
    );
}

static UITableViewCell *RKASettingsCellForRow(id self, SEL selector, UITableView *tableView, NSIndexPath *indexPath) {
    NSInteger originalCount = RKAOriginalSectionCount(self, tableView);
    if (indexPath.section == originalCount && indexPath.row == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = @"保持屏幕常亮";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
        toggle.on = RKAIsEnabled();
        toggle.accessibilityLabel = @"保持屏幕常亮";
        [toggle addTarget:[RKASettingsSwitchTarget sharedTarget]
                   action:@selector(valueChanged:)
         forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }

    return ((id (*)(id, SEL, UITableView *, NSIndexPath *))RKAOriginalCellForRow)(
        self, @selector(tableView:cellForRowAtIndexPath:), tableView, indexPath
    );
}

static BOOL RKAInstallClassMethodHook(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (!cls) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;

    const char *types = method_getTypeEncoding(method);
    IMP inheritedOrCurrent = method_getImplementation(method);
    if (class_addMethod(cls, selector, replacement, types)) {
        *original = inheritedOrCurrent;
    } else {
        *original = method_setImplementation(method, replacement);
    }
    return *original != NULL;
}

static void RKAInstallSettingsSwitch(void) {
    Class settingsClass = NSClassFromString(@"Reynard.SettingsViewController");
    if (!settingsClass) {
        settingsClass = NSClassFromString(@"_TtC7Reynard22SettingsViewController");
    }
    if (!settingsClass) return;

    BOOL sections = RKAInstallClassMethodHook(
        settingsClass, @selector(numberOfSectionsInTableView:),
        (IMP)RKASettingsNumberOfSections, &RKAOriginalNumberOfSections
    );
    BOOL rows = RKAInstallClassMethodHook(
        settingsClass, @selector(tableView:numberOfRowsInSection:),
        (IMP)RKASettingsNumberOfRows, &RKAOriginalNumberOfRows
    );
    BOOL header = RKAInstallClassMethodHook(
        settingsClass, @selector(tableView:titleForHeaderInSection:),
        (IMP)RKASettingsHeaderTitle, &RKAOriginalHeaderTitle
    );
    BOOL cell = RKAInstallClassMethodHook(
        settingsClass, @selector(tableView:cellForRowAtIndexPath:),
        (IMP)RKASettingsCellForRow, &RKAOriginalCellForRow
    );

    if (!(sections && rows && header && cell)) {
        NSLog(@"[ReynardKeepAwake] Settings switch installation incomplete: sections=%d rows=%d header=%d cell=%d",
              sections, rows, header, cell);
    } else {
        NSLog(@"[ReynardKeepAwake] Settings switch installed");
    }
}

__attribute__((constructor)) static void ReynardKeepAwakeInit(void) {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        NSSet *supportedBundleIDs = [NSSet setWithObjects:
            @"com.minh-ton.Reynard",
            @"com.r2",
            nil
        ];
        if (![supportedBundleIDs containsObject:bundleID]) {
            NSLog(@"[ReynardKeepAwake] Unsupported bundle ID: %@", bundleID);
            return;
        }
        NSLog(@"[ReynardKeepAwake] Loaded for bundle ID: %@", bundleID);
        dispatch_async(dispatch_get_main_queue(), ^{
            RKAInstallIdleTimerHook();
            if (!RKAHookInstalled) return;

            RKAInstallSettingsSwitch();

            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                RKAApplyCurrentPreference();
            }];
            [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                RKARestoreAppRequest();
            }];
            [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
                RKARestoreAppRequest();
            }];

            RKAApplyCurrentPreference();
        });
    }
}
