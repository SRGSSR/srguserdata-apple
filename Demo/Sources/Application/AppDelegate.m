//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AppDelegate.h"

#import "HistoryViewController.h"
#import "MediasViewController.h"
#import "PlaylistsViewController.h"
#import "PreferencesViewController.h"
#import "SettingsViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

@implementation AppDelegate

#pragma mark UIApplicationDelegate protocol

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];
    
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://hummingbird.rts.ch/api/profile"]
                                                                                       websiteURL:[NSURL URLWithString:@"https://www.rts.ch/profile"]];
    
    NSString *cachesDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSURL *fileURL = [[NSURL fileURLWithPath:cachesDirectory] URLByAppendingPathComponent:@"UserData-demo.sqlite"];
    SRGUserData.currentUserData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                                 serviceURL:[NSURL URLWithString:@"https://profil.rts.ch/api"]
                                                            identityService:SRGIdentityService.currentIdentityService];
    
    SRGDataProvider.currentDataProvider = [[SRGDataProvider alloc] initWithServiceURL:SRGIntegrationLayerProductionServiceURL()];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(userDidLogout:)
                                               name:SRGIdentityServiceUserDidLogoutNotification
                                             object:nil];
    
    MediasViewController *mediasViewController = [[MediasViewController alloc] init];
    HistoryViewController *historyViewController = [[HistoryViewController alloc] init];
    PlaylistsViewController *playlistsViewController = [[PlaylistsViewController alloc] init];
    PreferencesViewController *preferencesViewController = [[PreferencesViewController alloc] initWithPath:nil inDomain:@"userdata-demo"];
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
    
#if TARGET_OS_IOS
    UINavigationController *mediasNavigationController = [[UINavigationController alloc] initWithRootViewController:mediasViewController];
    mediasNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Medias", nil) image:[UIImage imageNamed:@"media"] tag:0];
    
    UINavigationController *historyNavigationController = [[UINavigationController alloc] initWithRootViewController:historyViewController];
    historyNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"History", nil) image:[UIImage imageNamed:@"history"] tag:1];
    
    UINavigationController *playlistsNavigationController = [[UINavigationController alloc] initWithRootViewController:playlistsViewController];
    playlistsNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Playlists", nil) image:[UIImage imageNamed:@"playlists-large"] tag:2];
    
    UINavigationController *preferencesNavigationController = [[UINavigationController alloc] initWithRootViewController:preferencesViewController];
    preferencesNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Preferences", nil) image:[UIImage imageNamed:@"preferences"] tag:3];
    
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    settingsNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil) image:[UIImage imageNamed:@"settings"] tag:4];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[ mediasNavigationController, historyNavigationController, playlistsNavigationController, preferencesNavigationController, settingsNavigationController ];
    self.window.rootViewController = tabBarController;
#else
    mediasViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Medias", nil) image:nil tag:0];
    historyViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"History", nil) image:nil tag:1];
    playlistsViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Playlists", nil) image:nil tag:2];
    preferencesViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Preferences", nil) image:nil tag:3];
    settingsViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil) image:nil tag:4];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[ mediasViewController, historyViewController, playlistsViewController, preferencesViewController, settingsViewController ];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:tabBarController];
    self.window.rootViewController = navigationController;
#endif
    
    return YES;
}

#pragma mark Notifications

- (void)userDidLogout:(NSNotification *)notification
{
    if ([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Information", nil)
                                                                                 message:NSLocalizedString(@"You have been logged out. Please login again to synchronize your data.", nil)
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleCancel handler:nil]];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
}

@end
