Getting started
===============

This getting started guide discusses all concepts required to use the SRG User Data library.

### Service instantiation

SRG User Data provides an efficient way to save and retrieve user-specific data (currently history data) from local storage. This data can be optionally synchronized with a user account, provided an [identity service](https://github.com/SRGSSR/srgidentity-ios) has bound at instantiation time.

#### Offline user data

To instantiate a purely local user data storage without account synchronization, simply instantiate an `SRGUserData` object by providing a file URL where data will be saved:

```objective-c
SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                       serviceURL:nil
                                                  identityService:nil];
```

#### Online user data

To instantiate a user data storage which can synchronized with a user account if a user logs in, you must provide an `SRGIdentityService` at creation time. For user data to be synchronized, an associated service URL is required as well:

```objective-c
SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                       serviceURL:serviceURL
                                                  identityService:identityService];
```

#### Shared instance

You can have several `SRGUserData` instances in an application, though most applications should require only one. To make it easier to access the main instance for an application, the `SRGUserData ` class provides a class property to set and retrieve it as shared instance:

```objective-c
SRGUserData.currentUserData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                             serviceURL:serviceURL
                                                        identityService:identityService];
```

For simplicity, this getting started guide assumes that a shared instance has been set. If you cannot use the shared instance, store the objects you instantiated somewhere and provide access to them in some way.

### User information

The `SRGUserData` `user` property provides information about the current user. Note that a single user is always available, whether this user is logged in or not.

### Saving and retrieving history data

To access history data, use `SRGUserData` `history` property. The return `SRGHistory` instance provides several methods to read history entries from the local store, e.g.

```objective-c
NSArray<SRGHistoryEntry *> *historyEntries = [SRGUserData.currentUserData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
```

or to save / update an entry:

```objective-c
[SRGUserData.currentUserData.history saveHistoryEntryWithUid:@"media_id" lastPlaybackTime:CMTimeMakeWithSeconds(100., NSEC_PER_SEC) deviceUid:@"My device" completionBlock:nil];
```

For performance reasons writes are always made asynchronously, calling a block on completion. Reads can be made synchronously or asynchronously depending on your needs.

### Notifications

History changes are notified through `SRGHistoryDidChangeNotification`, whether a user is logged in or not. This ensures any part of your application can stay informed about changes and respond accordingly.

Once a user has logged in with an associated `SRGIdentityService` instance, history data will stay automatically synchronized. Your application can register to the `SRGUserDataDidStartSynchronizationNotification` and `SRGUserDataDidFinishSynchronizationNotification` notifications to detect when global synchronization starts or ends. For information purposes, the last synchronization date can also be retrieved from the `SRGUserData` `user` information.

### Thread-safety considerations

When retrieving data asynchronously, beware that returned objects are most probably Core Data managed objects. Such objects cannot be exchanged between threads and must be consumed where they are received.
