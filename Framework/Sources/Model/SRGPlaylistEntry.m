//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPlaylistEntry.h"

#import "SRGUserObject+Subclassing.h"

#import <libextobjc/libextobjc.h>

@interface SRGPlaylistEntry ()

@property (nonatomic) SRGPlaylist *playlist;

@end

@implementation SRGPlaylistEntry

@dynamic playlist;

#pragma mark Overrides

+ (NSString *)uidKey
{
    return @"itemId";
}

@end
