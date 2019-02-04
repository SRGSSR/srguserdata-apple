//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreData/CoreData.h>

@class SRGHistoryEntry;

NS_ASSUME_NONNULL_BEGIN

/**
 *  User information.
 */
@interface SRGUser : NSManagedObject

// TODO: Hide implementation details, provide only read-only objects to SDK users

/**
 *  Setup a main user.
 *
 *  @discussion An exception will be raised if `+mainUserInManagedObjectContext:` is called without a user having been
 *              setup (and properly committed).
 */
+ (void)setupMainUserWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  The main user of the application.
 */
+ (SRGUser *)mainUserInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 *  Detach the user, returning it to a non-logged in state.
 */
- (void)detach;

@end

NS_ASSUME_NONNULL_END

#import "SRGUser+CoreDataProperties.h"          // Generated and managed by Xcode
