//
//  AppDelegate.m
//  LoLBookOfChampions
//
//  Created by Jeff Roberts on 1/19/15.
//  Copyright (c) 2015 nimbleNoggin.io. All rights reserved.
//

#import "AppDelegate.h"
#import "NIODataDragonSyncService.h"
#import "NIODataDragonContract.h"
#import "NIOTaskFactory.h"


@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [self initializeApplication];
	LOLLogVerbose(@"Application did finish launching");
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	LOLLogVerbose(@"Application will enter foreground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	LOLLogVerbose(@"Application did become active");

	[self.dataDragonSyncService sync];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

-(void)initializeApplication {
	self.window.frame = self.mainScreen.bounds;
	[NIODataDragonContract contentAuthorityBase:self.bundleIdentifier];
	[self initializeLogger];
	[self initializeApplicationCache];
}

-(void)initializeApplicationCache {
	NSURLCache *sharedCache = [[NSURLCache alloc]
			initWithMemoryCapacity:2 * 1024 * 1024
					  diskCapacity:400 * 1024 * 1024
						  diskPath:@"champImageCache"];

	[NSURLCache setSharedURLCache:sharedCache];
}

-(void)initializeLogger {
	for ( DDAbstractLogger *logger in self.loggers ) {
		[DDLog addLogger:logger];
	}
}

@end
