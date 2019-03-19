//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGUserObject.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Methods for subclasses to implement deserialization from the service JSON format, and serialization to the service
 *  JSON format.
 */
@interface SRGUserObject (Subclassing)

/**
 *  Update the current entry using the provided dictionary, in the format delivered by the associated service.
 */
- (void)updateWithDictionary:(NSDictionary *)dictionary NS_REQUIRES_SUPER;

/**
 *  Return a dictionary representation of the entry, which can be sent to the associated service.
 *
 *  @discussion Subclasses must call the parent method implementation to get the initial dictionary to start from.
 */
@property (nonatomic, readonly) NSDictionary *dictionary;

@end

NS_ASSUME_NONNULL_END
