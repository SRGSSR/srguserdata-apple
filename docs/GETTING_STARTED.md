Getting started
===============

This getting started guide discusses all concepts required to use the SRG User Data library.

### Service instantiation

SRG User Data provides an efficient way to save and retrieve user-specific data from local storage. This data can be optionally and transparently synchronized with a user account, provided an [identity service](https://github.com/SRGSSR/srgidentity-apple) has been bound at instantiation time.

#### Offline user data

To instantiate a purely local user data storage without account synchronization, simply instantiate an `SRGUserData` object by providing a file URL where data will be saved:

```objective-c
SRGUserData *userData = [[SRGUserData alloc] initWithStoreFileURL:fileURL
                                                       serviceURL:nil
                                                  identityService:nil];
```

#### Online user data

To instantiate a user data storage which can synchronized with a user account if a user logs in, you must provide an `SRGIdentityService` at creation time. For user data to be synchronized, an associated service URL is required:

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

### Playback history

`SRGUserData` provides the `history` property as an entry point to playback history management. The returned `SRGHistory` instance provides methods to add or update entries asynchronously:

```objective-c
[SRGUserData.currentUserData.history saveHistoryEntryWithUid:@"media_id" lastPlaybackTime:CMTimeMakeWithSeconds(100., NSEC_PER_SEC) deviceUid:@"My device" completionBlock^(NSError * _Nonnull error) {
    // ...
}];
```

and to read history entries from the local store synchronously, e.g.:

```objective-c
NSArray<SRGHistoryEntry *> *historyEntries = [SRGUserData.currentUserData.history historyEntriesMatchingPredicate:nil sortedWithDescriptors:nil];
// ...
```

For performance reasons writes are always made asynchronously, calling a block on completion. An opaque task identifier is returned from all asynchronous operations to let you cancel them if required. Reads can be made synchronously or asynchronously depending on your needs.

#### Change notifications

History changes are notified through `SRGHistoryEntriesDidChangeNotification` notifications, whether a user is logged in or not. This ensures any part of your application can stay informed about changes and respond accordingly.

### Playlists

`SRGUserData` provides the `playlists` property as an entry point to playlist management. There are two major types of playlists:

* User playlists which can be created, edited and deleted.
* Default playlists, which cannot be edited or deleted (e.g. the _Watcher later_ playlist), but whose items can be managed.

Creating a playlist is straigthforward:

```objective-c
[SRGUserData.currentUserData.playlists savePlaylistWithName:@"Sports" uid:nil completionBlock:^(NSString * _Nullable uid, NSError * _Nullable error) {
    // ...  
}];
```

A unique identifier can be specified to update an existing playlist or create one with a specific identifier. If not specified an identifier will be automatically generated and returned to the completion block for information. Default playlists are identified by specific reserved identifiers (for example `SRGPlaylistUidWatchLater` for the _Watch later_ playlist) and cannot be edited or deleted.

Once you have a playlist with a known identifier, you can add entries to it. For example, here is how you add a new media to the _Watch later_ playlist:

```objective-c
[SRGUserData.currentUserData.playlists savePlaylistEntryWithUid:@"media_id" inPlaylistWithUid:SRGPlaylistUidWatchLater completionBlock:^(NSError * _Nullable error) {
    // ...
}];
```

You can at any time retrieve the list of playlists:

```objective-c
NSArray<SRGPlaylist *> *playlists = [SRGUserData.currentUserData.playlists playlistsMatchingPredicate:nil sortedWithDescriptors:nil];
// ...
```

or entries for a specific playlist:

```objective-c
NSArray<SRGPlaylistEntry *> *playlistEntries = [SRGUserData.currentUserData.playlists playlistEntriesInPlaylistWithUid:SRGPlaylistUidWatchLater matchingPredicate:nil sortedWithDescriptors:nil];
// ...
```
Reads can be made synchronously or asynchronously depending on your needs.

#### Change notifications

Playlist changes are notified through `SRGPlaylistsDidChangeNotification` notifications, and playlist entry updates through `SRGPlaylistEntriessDidChangeNotification` notifications, whether a user is logged in or not. This ensures any part of your application can stay informed about changes and respond accordingly.

### Preferences

`SRGUserData` provides the `preferences` property as an entry point to read and write preferences. Similar to `NSUserDefaults`, preferences store settings, mostly strings and numbers. These settings are saved in a tree whose paths can be accessed as in a filesystem within domains, providing a way to contextually group settings, typically by application.

For example, you could set an HD download setting flag as follows for some application:

```objective-c
[SRGUserData.currentUserData.playlists.preferences setNumber:@YES atPath:@"settings/downloads/hd" inDomain:@"my_app"];
```

You can then retrieve the value in a similar way:

```objective-c
BOOL HDEnabled = [SRGUserData.currentUserData.playlists.preferences numberAtPath:@"settings/downloads/hd" inDomain:@"my_app"].boolValue;
```

#### Change notifications

Changes made to preferences are notified through `SRGPreferencesDidChangeNotification` notifications, whether a user is logged in or not. This ensures any part of your application can stay informed about changes and respond accordingly.

### Synchronization with a user account

Once a user has logged in with an associated `SRGIdentityService` instance, user data will stay automatically synchronized. Your application can register to the `SRGUserDataDidStartSynchronizationNotification` and `SRGUserDataDidFinishSynchronizationNotification` notifications to detect when global synchronization starts or ends. The end notification might contain error information if the synchronization went wrong for some reason.

For information purposes, the last successful synchronization date can be retrieved from the `SRGUserData` `user` information.

### Thread-safety considerations

When retrieving data asynchronously, beware that returned objects are most probably Core Data managed objects. Such objects cannot be exchanged between threads and must be consumed where they are received.

### Core Data compilation errors

Running on Mac OS Ventura, some non-blocking errors might appear during the compilation. `xcodebuild archive` is impacted and fails.
Adding write permissions on mapping models fixes this issue. In a project using SRG User Data:

- Add a new run script action as a pre-action for the build scheme.
- Paste this script:

```
# Get SRGUserData checkout path.
SRG_USER_DATA=$(find "$DERIVED_DATA_DIR" -path "*/SourcePackages/checkouts/srguserdata-apple" -type d)

# Apply SRGUserData script.
sh "$SRG_USER_DATA/Scripts/coredata-compilation-fix.sh" "$SRG_USER_DATA"
```
