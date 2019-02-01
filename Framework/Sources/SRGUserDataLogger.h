//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGLogger/SRGLogger.h>

/**
 *  Helper macros for logging.
 */
#define SRGUserDataLogVerbose(category, format, ...) SRGLogVerbose(@"ch.srgssr.userdata", category, format, ##__VA_ARGS__)
#define SRGUserDataLogDebug(category, format, ...)   SRGLogDebug(@"ch.srgssr.userdata", category, format, ##__VA_ARGS__)
#define SRGUserDataLogInfo(category, format, ...)    SRGLogInfo(@"ch.srgssr.userdata", category, format, ##__VA_ARGS__)
#define SRGUserDataLogWarning(category, format, ...) SRGLogWarning(@"ch.srgssr.userdata", category, format, ##__VA_ARGS__)
#define SRGUserDataLogError(category, format, ...)   SRGLogError(@"ch.srgssr.userdata", category, format, ##__VA_ARGS__)
