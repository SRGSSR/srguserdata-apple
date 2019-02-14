//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AppDelegate.h"

#import "DemosViewController.h"

#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

@implementation AppDelegate

#pragma mark UIApplicationDelegate protocol

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];
    
    SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://hummingbird.rts.ch/api/profile"]
                                                                                       websiteURL:[NSURL URLWithString:@"https://www.rts.ch/profile"]];
    
    NSString *libraryDirectory = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *fileURL = [[NSURL fileURLWithPath:libraryDirectory] URLByAppendingPathComponent:@"UserData-demo.sqlite"];
    SRGUserData.currentUserData = [[SRGUserData alloc] initWithIdentityService:SRGIdentityService.currentIdentityService
                                                             historyServiceURL:[NSURL URLWithString:@"https://profil.rts.ch/api/history"]
                                                                  storeFileURL:fileURL];
    
    SRGDataProvider.currentDataProvider = [[SRGDataProvider alloc] initWithServiceURL:SRGIntegrationLayerProductionServiceURL()];
    
    DemosViewController *demosViewController = [[DemosViewController alloc] init];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:demosViewController];
    return YES;
}

@end
