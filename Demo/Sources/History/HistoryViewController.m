//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HistoryViewController.h"

#import "PlayerViewController.h"
#import "SRGUserData_demo-Swift.h"

@import libextobjc;
@import SRGDataProviderNetwork;
@import SRGUserData;

@interface HistoryViewController ()

@property (nonatomic) NSArray<SRGMedia *> *medias;

@property (nonatomic, weak) SRGBaseRequest *request;

@end

@implementation HistoryViewController

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"History", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(historyDidChange:)
                                               name:SRGHistoryEntriesDidChangeNotification
                                             object:SRGUserData.currentUserData.history];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"MediaCell"];
}

#pragma mark Subclassing hooks

- (void)refresh
{
    if (self.request.running) {
        return;
    }
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGHistoryEntry.new, date) ascending:NO];
    [SRGUserData.currentUserData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:@[sortDescriptor] completionBlock:^(NSArray<SRGHistoryEntry *> * _Nullable historyEntries, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        NSArray<NSString *> *mediaURNs = [historyEntries valueForKeyPath:@keypath(SRGHistoryEntry.new, uid)];
        SRGBaseRequest *request = [[SRGDataProvider.currentDataProvider mediasWithURNs:mediaURNs completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (error) {
                return;
            }
            
            [self.tableView reloadDataAnimatedWithOldObjects:self.medias newObjects:medias section:0 updateData:^{
                self.medias = medias;
            }];
        }] requestWithPageSize:50];
        [request resume];
        self.request = request;;
    }];
}

- (void)cancelRefresh
{
    [self.request cancel];
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.medias.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:@"MediaCell"];
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.textLabel.text = self.medias[indexPath.row].title;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SRGMedia *media = self.medias[indexPath.row];
    SRGHistoryEntry *historyEntry = [SRGUserData.currentUserData.history historyEntryWithUid:media.URN];
    
#if TARGET_OS_IOS
    PlayerViewController *playerViewController = [[PlayerViewController alloc] initWithURN:media.URN time:historyEntry.lastPlaybackTime playerPlaylist:nil];
    playerViewController.modalPresentationStyle = UIModalPresentationFullScreen;
#else
    SRGLetterboxViewController *playerViewController = LetterboxPlayerViewController(media.URN, historyEntry.lastPlaybackTime, nil);
#endif
    [self presentViewController:playerViewController animated:YES completion:nil];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        SRGMedia *media = self.medias[indexPath.row];
        [SRGUserData.currentUserData.history discardHistoryEntriesWithUids:@[media.URN] completionBlock:nil];
    }
}

#pragma mark Notifications

- (void)historyDidChange:(NSNotification *)notification
{
    [self refresh];
}

@end
