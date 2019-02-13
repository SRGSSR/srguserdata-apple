//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Person.h"

@implementation Person

- (BOOL)validateName:(NSString **)pName error:(NSError *__autoreleasing *)pError
{
    NSParameterAssert(pName);
    
    if (! *pName) {
        if (pError) {
            *pError = [NSError errorWithDomain:@"ch.srgssr.userdata-tests.validation" code:1012 userInfo:nil];
        }
        return NO;
    }
    
    return YES;
}

@end
