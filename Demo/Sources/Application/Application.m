//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Application.h"

#import "HistoryViewController.h"
#import "MediasViewController.h"
#import "PlaylistsViewController.h"
#import "PreferencesViewController.h"
#import "SettingsViewController.h"

UIViewController *ApplicationRootViewController(void)
{
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
    return tabBarController;
#else
    mediasViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Medias", nil) image:nil tag:0];
    historyViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"History", nil) image:nil tag:1];
    playlistsViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Playlists", nil) image:nil tag:2];
    preferencesViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Preferences", nil) image:nil tag:3];
    settingsViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil) image:nil tag:4];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[ mediasViewController, historyViewController, playlistsViewController, preferencesViewController, settingsViewController ];
    
    return [[UINavigationController alloc] initWithRootViewController:tabBarController];
#endif
}
