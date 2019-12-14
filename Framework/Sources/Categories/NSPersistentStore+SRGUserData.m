//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSPersistentStore+SRGUserData.h"

@implementation NSPersistentContainer (SRGUserData)

- (void)srg_loadPersistentStoreWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    [self loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription * _Nonnull persistentStoreDescription, NSError * _Nullable error) {
        completionHandler(error);
    }];
}

- (NSURL *)srg_fileURL
{
    return self.persistentStoreDescriptions.firstObject.URL;
}

@end

