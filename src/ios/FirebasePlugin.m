#import "FirebasePlugin.h"
#import <Cordova/CDV.h>
#import "AppDelegate.h"
#import "Firebase.h"
@import FirebaseInstanceID;
@import FirebaseMessaging;
@import FirebaseAnalytics;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif

#ifndef NSFoundationVersionNumber_iOS_9_x_Max
#define NSFoundationVersionNumber_iOS_9_x_Max 1299
#endif

@implementation FirebasePlugin

@synthesize notificationCallbackId;
@synthesize tokenRefreshCallbackId;
@synthesize registerCallbackId;
@synthesize notificationStack;


static NSInteger const kNotificationStackSize = 10;
static FirebasePlugin *firebasePlugin;

+ (FirebasePlugin *) firebasePlugin {
    return firebasePlugin;
}

- (void)pluginInitialize {
    NSLog(@"Starting Firebase plugin");
    firebasePlugin = self;
}

// DEPRECATED - alias of getToken
- (void)getInstanceId:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:
                    [[FIRInstanceID instanceID] token]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getToken:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:
                    [[FIRInstanceID instanceID] token]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)grantPermission:(CDVInvokedUrlCommand *)command {
    if (self.registerCallbackId != nil) {
      // registration already in process, return error       
      CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"grantPermission already in process"];
      [self.commandDelegate sendPluginResult:commandResult callbackId:self.registerCallbackId];
      return;
    }

    self.registerCallbackId = command.callbackId;

    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        if ([[UIApplication sharedApplication]respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationType notificationTypes =
            (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        } else {
            #pragma GCC diagnostic push
            #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
            #pragma GCC diagnostic pop
        }
    } else {
        #if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        // IOS 10
        UNAuthorizationOptions authOptions =
          UNAuthorizationOptionAlert
          | UNAuthorizationOptionSound
          | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter]
          requestAuthorizationWithOptions:authOptions
          completionHandler:^(BOOL granted, NSError * _Nullable error) {
          }
        ];
        [[UNUserNotificationCenter currentNotificationCenter] setDelegate:self];
        [[FIRMessaging messaging] setRemoteMessageDelegate:self];
        #endif

        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }

    //CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    //[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"[Push] applicationDidBecomeActive");
   
    if (self.registerCallbackId != nil) {
        NSLog(@"[Push] registering checkUserNotificationSettings");
        [self performSelector:@selector(checkUserNotificationSettings) withObject:nil afterDelay:1];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    NSLog(@"[Push] applicationWillResignActive");
}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"[Push] didRegisterForRemoteNotificationsWithDeviceToken");
    if (self.registerCallbackId != nil)
    {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"%@", deviceToken]];
        [self.commandDelegate sendPluginResult:commandResult callbackId:self.registerCallbackId];
    } else {
        NSLog(@"[Push] didRegisterForRemoteNotificationsWithDeviceToken == no callBack");

    }
    self.registerCallbackId = nil;
}

- (void)checkUserNotificationSettings {
    NSLog(@"[Push] Check user Notification Settings");
    if (self.registerCallbackId != nil) {
        bool registered =[[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
        //UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        
        //if (types == UIRemoteNotificationTypeNone) {
        if (!registered) {
            NSLog(@"[Push] User aborted push");

            CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"userAborted"];
            [self.commandDelegate sendPluginResult:commandResult callbackId:self.registerCallbackId];
            self.registerCallbackId = nil;
        } else {
            NSLog(@"[Push] User accepted push");
        }
    }
    
    
}

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    if (self.registerCallbackId != nil)
    {
        NSString        *errorMessage = (error) ? [NSString stringWithFormat:@"%@", [error localizedDescription]] : @"Unexpected error";
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:commandResult callbackId:self.registerCallbackId];
    }
    self.registerCallbackId = nil;
}


- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
    int number = [[command.arguments objectAtIndex:0] intValue];

    [self.commandDelegate runInBackground:^{
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:number];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        long badge = [[UIApplication sharedApplication] applicationIconBadgeNumber];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:badge];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)subscribe:(CDVInvokedUrlCommand *)command {
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];
    
    [[FIRMessaging messaging] subscribeToTopic: topic];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];
    
    [[FIRMessaging messaging] unsubscribeFromTopic: topic];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command {
    self.notificationCallbackId = command.callbackId;

    if (self.notificationStack != nil && [self.notificationStack count]) {
        for (NSDictionary *userInfo in self.notificationStack) {
            [self sendNotification:userInfo];
        }
        [self.notificationStack removeAllObjects];
    }
}

- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
    self.tokenRefreshCallbackId = command.callbackId;
    NSString* currentToken = [[FIRInstanceID instanceID] token];
    if (currentToken != nil) {
        [self sendToken:currentToken];
    }
}

- (void)sendNotification:(NSDictionary *)userInfo {
    if (self.notificationCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userInfo];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.notificationCallbackId];
    } else {
        if (!self.notificationStack) {
            self.notificationStack = [[NSMutableArray alloc] init];
        }
        
        // stack notifications until a callback has been registered
        [self.notificationStack addObject:userInfo];

        if ([self.notificationStack count] >= kNotificationStackSize) {
            [self.notificationStack removeLastObject];
        }
    }
}

- (void)sendToken:(NSString *)token {
    if (self.tokenRefreshCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.tokenRefreshCallbackId];
    }
}

- (void)logEvent:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSDictionary* parameters = [command.arguments objectAtIndex:1];
        
        [FIRAnalytics logEventWithName:name parameters:parameters];
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* id = [command.arguments objectAtIndex:0];
        
        [FIRAnalytics setUserID:id];
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSString* value = [command.arguments objectAtIndex:1];
        
        [FIRAnalytics setUserPropertyString:value forName:name];
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end
