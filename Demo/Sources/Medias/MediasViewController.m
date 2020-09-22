//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediasViewController.h"

#import "PlayerViewController.h"
#import "SRGUserData_demo-Swift.h"

@import SRGDataProviderNetwork;
@import SRGUserData;

@interface MediasViewController ()

@property (nonatomic) NSArray<SRGMedia *> *medias;
@property (nonatomic, weak) SRGBaseRequest *request;

@end

@implementation MediasViewController

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"Medias", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"MediaCell"];
}

#pragma mark Subclassing hooks

- (void)refresh
{
    if (self.request.running) {
        return;
    }
    
    SRGBaseRequest *request = [[SRGDataProvider.currentDataProvider tvMostPopularMediasForVendor:SRGVendorRTS withCompletionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        [self.tableView reloadDataAnimatedWithOldObjects:self.medias newObjects:medias section:0 updateData:^{
            self.medias = medias;
        }];
    }] requestWithPageSize:50];
    [request resume];
    self.request = request;
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

@end
