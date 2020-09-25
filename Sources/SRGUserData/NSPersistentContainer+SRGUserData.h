//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGPersistentContainer.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Compatibility layer with `NSPersistentContainer`.
 */
// TODO: Remove when iOS 10 is the minimum supported version
@interface NSPersistentContainer (SRGPersistentContainerCompatibility) <SRGPersistentContainer>

@end

NS_ASSUME_NONNULL_END
