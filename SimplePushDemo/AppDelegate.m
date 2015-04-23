//
//  AppDelegate.m
//  SimplePushDemo
//
//  Created by mozilla on 2/17/15.
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

NSMutableDictionary *settings;
NSData *apnsToken;
ViewController *view;

- (id)objectForKey:(NSString*)key {
    @try {
    return [settings objectForKey:key];
    }
    @catch (NSException *exception) {
        NSLog(@"No key %@", key);
        return nil;
    }
    @finally {
    }
}

- (void) setValue:(id)value forKey:(NSString*)key {
    if (settings == nil) {
        NSLog(@"Emergency alloc of settings");
        settings = [NSMutableDictionary alloc];
    }
    [settings setValue:value forKey:key];
}

- (NSString *)getTokenAsString {
    NSData *token;
    token = apnsToken;
    if (token == nil) {
        if ([self objectForKey:@"token"] == nil){
            return @"";
        }
        token = (NSData *)[self objectForKey:@"token"];
    }
    const unsigned char *bytes = (const unsigned char *)[token bytes];
    NSUInteger len = [token length];
    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:len*2];
    for (int i=0;i<len;i++) {
        [hex appendFormat: @"%02x", bytes[i]];
    }
    return (NSString *)hex;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]){
        [application registerUserNotificationSettings:[
                UIUserNotificationSettings settingsForTypes:
                        UIUserNotificationTypeAlert |
                        UIUserNotificationTypeSound |
                        UIUserNotificationTypeBadge |
                        UIUserNotificationTypeNone categories: nil]];
    }
    // application windows
    view = (ViewController*) self.window.rootViewController;
    [view log:@"here"];
    return YES;
}

- (void) application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    // ViewController values are exposed
    // e.g. endpoint == nil at this time.
    // because that sort of thing is obvious to anyone familiar with object theory.
    // ಠ_ಠ
    if ([application isRegisteredForRemoteNotifications]) {
        NSLog(@"Can get remote notifications");
    }
    NSLog(@"got Register Data");
    if ([application respondsToSelector:@selector(registerForRemoteNotifications)]){
        // In order for this to work, you'll need to provision a profile on:
        // https://developer.apple.com/account/ios/profile/profileList.action?type=limited
        // that is tied to the exact matching AppID for this app.
        // Remember, you'll need a specific iOS Development cert that exactly matches the BundleID specified in the
        // Project description (e.g. this app's bundle ID is "com.jrconlin.SimplePushDemo"
        NSLog(@"Registering for remote notifications...");
        [application registerForRemoteNotifications];
    }
}

- (void) application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(error.description);
}

- (void) application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    apnsToken = deviceToken;
    [self setValue: deviceToken forKey:@"token"];
    NSLog(@"got remote token %@", [self getTokenAsString]);
}
// TODO: These currently don't save state data from what I can see. Fortunately, they also don't return
// an error.
- (NSString *) saveFilePath {
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES);
    return [[path objectAtIndex:0] stringByAppendingPathComponent: @"state.plist"];
}

- (void)saveState {
    NSLog(@"Saving state...");
    
    NSString *file = [self saveFilePath];
    [settings writeToFile:file atomically:YES];
}

- (BOOL)restoreState {
    NSLog(@"Restoring state...");
    settings = [NSMutableDictionary alloc];
    NSString *file = [self saveFilePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath: file]) {
        settings = [settings initWithContentsOfFile:file];
        return true;
    }
    settings = [settings init];
    NSLog(@"No state to recover.");
    return false;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    //[self saveState];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    //[self saveState];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    //[self restoreState];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    //[self restoreState];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    // [self saveState];
    [self saveContext];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Success!
    // TODO: You want to record the userInfo struct if running in the background or disabled.
    //       then check for that info when re-enabled.
    NSLog([NSString stringWithFormat:@"Message: %@", [userInfo valueForKey:@"Msg"]]);
    NSLog([NSString stringWithFormat:@"Version: %@", [userInfo valueForKey:@"Ver"]]);
    // If we were going to do more here, this is where we would call fancier functions.
    [view log: [NSString stringWithFormat:@"Got APNS message!\nMsg from push: %@ : %@",[userInfo valueForKey:@"Msg"],[userInfo valueForKey:@"Ver"]]];
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler {
    if ([identifier isEqualToString:@"declineAction"]){
        NSLog(@"Declined notifications");
    } else if ([identifier isEqualToString:@"answerAction"]) {
        NSLog(@"Accepted");
    }
}


#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.jrconlin.SimplePushDemo" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"SimplePushDemo" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // Create the coordinator and store
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"SimplePushDemo.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

@end
