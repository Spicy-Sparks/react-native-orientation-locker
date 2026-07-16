//
//  react-native-orientation-locker
//  Orientation.m
//
//  Created by Wonday on 17/5/12.
//  Copyright (c) wonday.org All rights reserved.
//


#import "Orientation.h"


@implementation Orientation
{
#if (!TARGET_OS_TV)
    UIInterfaceOrientation _lastOrientation;
    UIInterfaceOrientation _lastDeviceOrientation;
    BOOL _disableFaceUpDown;
#endif
    BOOL _isLocking;
}

#if (!TARGET_OS_TV)
static UIInterfaceOrientationMask _orientationMask = UIInterfaceOrientationMaskAll;

+ (void)setOrientation: (UIInterfaceOrientationMask)orientationMask {
    _orientationMask = orientationMask;
}

+ (UIInterfaceOrientationMask)getOrientation {
    return _orientationMask;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"orientationDidChange",@"deviceOrientationDidChange",@"lockDidChange"];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _lastOrientation = [self getInterfaceOrientation];
        _lastDeviceOrientation = [self getDeviceOrientation];
        _isLocking = NO;
        _disableFaceUpDown = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
        // PATCH: removed `[self addListener:@"orientationDidChange"]`.
        // RCTEventEmitter's listener count is managed by the JS bridge; calling
        // addListener natively double-counts and, paired with the dealloc
        // removeListeners:1 below, triggers "Attempted to remove more Orientation
        // listeners than added" on module teardown under the New Architecture.
        // The NSNotificationCenter observer above already drives orientation
        // detection independently of the JS listener count.
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // PATCH: removed `[self removeListeners:1]` — see init. It decremented
    // the JS-managed RCTEventEmitter listener count that it never legitimately
    // owned, causing the "remove more than added" redbox on dealloc.
}

- (UIInterfaceOrientation)getInterfaceOrientation
{
    if(@available(iOS 13, *)) {
        UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;
        // connectedScenes is an unordered set that may hold non-window scenes
        // (e.g. CarPlay's CPTemplateApplicationScene). Blindly reading firstObject
        // would miss the real window scene and report UNKNOWN. Pick a real
        // UIWindowScene, preferring the foreground-active one.
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                windowScene = (UIWindowScene *)scene;
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    break;
                }
            }
        }
        if (windowScene != nil) {
            orientation = windowScene.interfaceOrientation;
        }
        
#if DEBUG
        if(orientation == UIInterfaceOrientationUnknown) {
            NSLog(@"Device orientation is unknown.");
        }
#endif
        
        return orientation;
    } else {
        return [UIApplication sharedApplication].statusBarOrientation;
    }
}

- (UIInterfaceOrientation)getDeviceOrientation {
    UIInterfaceOrientation deviceOrientation = (UIInterfaceOrientation) [UIDevice currentDevice].orientation;
    
    BOOL isFaceUpDown = deviceOrientation == UIDeviceOrientationFaceUp || deviceOrientation == UIDeviceOrientationFaceDown;
    if (_disableFaceUpDown && isFaceUpDown) {
        return [self getInterfaceOrientation];
    }
    
    return deviceOrientation;
}

- (void)deviceOrientationDidChange:(NSNotification *)notification
{
    UIInterfaceOrientation orientation = [self getInterfaceOrientation];
    UIInterfaceOrientation deviceOrientation = [self getDeviceOrientation];
    
    // do not send Unknown Orientation
    if (deviceOrientation==UIInterfaceOrientationUnknown) {
        return;
    }
    
    if (orientation!=UIInterfaceOrientationUnknown && orientation!=_lastOrientation) {
        [self sendEventWithName:@"orientationDidChange" body:@{@"orientation": [self getOrientationStr:orientation]}];
        _lastOrientation = orientation;
    }
    
    // when call lockToXXX, not sent deviceOrientationDidChange
    if (!_isLocking && deviceOrientation!=_lastDeviceOrientation) {
        [self sendEventWithName:@"deviceOrientationDidChange" body:@{@"deviceOrientation":[self getOrientationStr:deviceOrientation]}];
        _lastDeviceOrientation = deviceOrientation;
    }
}

- (NSString *)getOrientationStr: (UIInterfaceOrientation)orientation {
    
    NSString *orientationStr;
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            orientationStr = @"PORTRAIT";
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            orientationStr = @"LANDSCAPE-RIGHT";
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            orientationStr = @"LANDSCAPE-LEFT";
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            orientationStr = @"PORTRAIT-UPSIDEDOWN";
            break;
            
        case UIDeviceOrientationFaceUp:
            orientationStr = @"FACE-UP";
            break;
            
        case UIDeviceOrientationFaceDown:
            orientationStr = @"FACE-DOWN";
            break;
            
        default:
            orientationStr = @"UNKNOWN";
            break;
    }
    return orientationStr;
}

- (void)lockToOrientation:(UIInterfaceOrientation) newOrientation usingMask:(UIInterfaceOrientationMask) mask  {
    // set a flag so that no deviceOrientationDidChange events are sent to JS
    _isLocking = YES;
    NSString* orientation = @"orientation";
    
    [Orientation setOrientation:mask];
    
    if (@available(iOS 16.0, *)) {
        // connectedScenes is an unordered set that may also contain non-window scenes
        // (e.g. CarPlay's CPTemplateApplicationScene). Those do not respond to
        // requestGeometryUpdateWithPreferences: and blind-casting firstObject to a
        // UIWindowScene raises NSInvalidArgumentException. Pick a real UIWindowScene,
        // preferring the foreground-active one.
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                windowScene = (UIWindowScene *)scene;
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    break;
                }
            }
        }

        if (windowScene != nil) {
            UIWindowSceneGeometryPreferencesIOS *geometryPreferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
            [windowScene requestGeometryUpdateWithPreferences:geometryPreferences errorHandler:^(NSError * _Nonnull error) {
#if DEBUG
                if (error) {
                    NSLog(@"Failed to update geometry with UIInterfaceOrientationMask: %@", error);
                }
#endif
            }];
        }

    } else {
        UIDevice* currentDevice = [UIDevice currentDevice];
        
        [currentDevice setValue:@(UIInterfaceOrientationUnknown) forKey:orientation];
        [currentDevice setValue:@(newOrientation) forKey:orientation];
    }
    
    [UIViewController attemptRotationToDeviceOrientation];
        
    [self sendEventWithName:@"lockDidChange" body:@{orientation: [self getOrientationStr:newOrientation]}];

    _isLocking = NO;
}

#else

- (NSArray<NSString *> *)supportedEvents
{
    return @[];
}

#endif

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(configure:(NSDictionary *)options)
{
#if DEBUG
    NSLog(@"Configure called with options: %@", options);
#endif
    
#if (!TARGET_OS_TV)
    NSNumber *disableFaceUpDown = [options objectForKey:@"disableFaceUpDown"];
    _disableFaceUpDown = [disableFaceUpDown boolValue];
#endif
}

RCT_EXPORT_METHOD(getOrientation:(RCTResponseSenderBlock)callback)
{
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        UIInterfaceOrientation orientation = [self getInterfaceOrientation];
        NSString *orientationStr = [self getOrientationStr:orientation];
        callback(@[orientationStr]);
    });
#endif
}

RCT_EXPORT_METHOD(getDeviceOrientation:(RCTResponseSenderBlock)callback)
{
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        UIInterfaceOrientation deviceOrientation = [self getDeviceOrientation];
        NSString *orientationStr = [self getOrientationStr:deviceOrientation];
        callback(@[orientationStr]);
    });
#endif
}

RCT_EXPORT_METHOD(lockToPortrait)
{
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self lockToOrientation:UIInterfaceOrientationPortrait usingMask:UIInterfaceOrientationMaskPortrait];
    });
#endif
}

RCT_EXPORT_METHOD(lockToPortraitUpsideDown)
{
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self lockToOrientation:UIInterfaceOrientationPortraitUpsideDown usingMask:UIInterfaceOrientationMaskPortraitUpsideDown];
    });
#endif
}

RCT_EXPORT_METHOD(lockToLandscape)
{
#if DEBUG
    NSLog(@"Locking to Landscape");
#endif
    
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        UIInterfaceOrientation orientation = [self getInterfaceOrientation];
        NSString *orientationStr = [self getOrientationStr:orientation];

        // Rotate via lockToOrientation: so iOS 16+ uses requestGeometryUpdate.
        // The previous body relied only on [UIDevice setValue:forKey:@"orientation"],
        // a private KVC hack that is a silent no-op on iOS 16+ (rotation there requires
        // the geometry API). The mask keeps "either landscape edge"; the concrete
        // orientation only drives the pre-iOS-16 KVC path and matches the edge the
        // device is already closest to. lockToOrientation: handles _isLocking, the
        // scene selection (CarPlay-safe) and the lockDidChange event.
        if ([orientationStr isEqualToString:@"LANDSCAPE-RIGHT"]) {
            [self lockToOrientation:UIInterfaceOrientationLandscapeLeft usingMask:UIInterfaceOrientationMaskLandscape];
        } else {
            [self lockToOrientation:UIInterfaceOrientationLandscapeRight usingMask:UIInterfaceOrientationMaskLandscape];
        }
    });
#endif
}

RCT_EXPORT_METHOD(lockToLandscapeRight)
{
#if DEBUG
    NSLog(@"Locking to Landscape Right");
#endif
    
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self lockToOrientation:UIInterfaceOrientationLandscapeLeft usingMask:UIInterfaceOrientationMaskLandscapeLeft];
    });
#endif
}

RCT_EXPORT_METHOD(lockToLandscapeLeft)
{
#if DEBUG
    NSLog(@"Locking to Landscape Left");
#endif
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self lockToOrientation:UIInterfaceOrientationLandscapeRight usingMask:UIInterfaceOrientationMaskLandscapeRight];
    });
#endif
}

RCT_EXPORT_METHOD(lockToAllOrientationsButUpsideDown)
{
#if DEBUG
    NSLog(@"Locking to all except upside down");
#endif
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self lockToOrientation:UIInterfaceOrientationPortrait usingMask:UIInterfaceOrientationMaskAllButUpsideDown];
    });
#endif
}

RCT_EXPORT_METHOD(unlockAllOrientations)
{
#if DEBUG
    NSLog(@"Unlocking All Orientations");
#endif
    
#if (!TARGET_OS_TV)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self lockToOrientation:UIInterfaceOrientationUnknown usingMask:UIInterfaceOrientationMaskAll];
    });
#endif
}

- (NSDictionary *)constantsToExport
{
#if (!TARGET_OS_TV)
    UIInterfaceOrientation orientation = [self getInterfaceOrientation];
    NSString *orientationStr = [self getOrientationStr:orientation];
    
    return @{@"initialOrientation": orientationStr};
#endif
    return nil;
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

@end
