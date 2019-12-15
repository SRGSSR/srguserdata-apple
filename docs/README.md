[![SRG User Data logo](README-images/logo.png)](https://github.com/SRGSSR/srguserdata-apple)

[![GitHub releases](https://img.shields.io/github/v/release/SRGSSR/srguserdata-apple)](https://github.com/SRGSSR/srguserdata-apple/releases) [![platform](https://img.shields.io/badge/platfom-ios%20%7C%20tvos-blue)](https://github.com/SRGSSR/srguserdata-apple) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![GitHub license](https://img.shields.io/github/license/SRGSSR/srguserdata-apple)](https://github.com/SRGSSR/srguserdata-apple/blob/master/LICENSE)

## About

The SRG User Data framework provides easy user data management:

* Playback history.
* Playlists.
* Preferences.

User data storage can be bound to an [SRG Identity](https://github.com/SRGSSR/srgidentity-apple) service, so that logged in users can have their personal data automatically synchronized with their account, and thus available across devices.

## Compatibility

The library is suitable for applications running on iOS 9, tvOS 12 and above. The project is meant to be opened with the latest Xcode version.

## Contributing

If you want to contribute to the project, have a look at our [contributing guide](CONTRIBUTING.md).

## Installation

The library can be added to a project using [Carthage](https://github.com/Carthage/Carthage) by adding the following dependency to your `Cartfile`:
    
```
github "SRGSSR/srguserdata-apple"
```

For more information about Carthage and its use, refer to the [official documentation](https://github.com/Carthage/Carthage).

### Dependencies

The library requires the following frameworks to be added to any target requiring it:

* `FXReachability`: A reachability framework.
* `libextobjc`: A utility framework.
* `MAKVONotificationCenter`: A safe KVO framework.
* `Mantle`:  The framework used to parse the data.
* `SRGAppearance`: The appearance framework.
* `SRGIdentity`: The framework used to manage the user identity.
* `SRGLogger`: The framework used for internal logging.
* `SRGNetwork`: A networking framework.
* `UICKeyChainStore `: A keychain management framework.

### Dynamic framework integration

1. Run `carthage update` to update the dependencies (which is equivalent to `carthage update --configuration Release`). 
2. Add the frameworks listed above and generated in the `Carthage/Build/(iOS|tvOS)` folder to your target _Embedded binaries_.

If your target is building an application, a few more steps are required:

1. Add a _Run script_ build phase to your target, with `/usr/local/bin/carthage copy-frameworks` as command.
2. Add each of the required frameworks above as input file `$(SRCROOT)/Carthage/Build/(iOS|tvOS)/FrameworkName.framework`.

### Static framework integration

1. Run `carthage update --configuration Release-static` to update the dependencies. 
2. Add the frameworks listed above and generated in the `Carthage/Build/(iOS|tvOS)/Static` folder to the _Linked frameworks and libraries_ list of your target.
3. Also add any resource bundle `.bundle` found within the `.framework` folders to your target directly.
4. Add the `-all_load` flag to your target _Other linker flags_.

## Building the project

A [Makefile](../Makefile) provides several targets to build and package the library. The available targets can be listed by running the following command from the project root folder:

```
make help
```

Alternatively, you can of course open the project with Xcode and use the available schemes.

## Usage

When you want to use classes or functions provided by the library in your code, you must import it from your source files first.

### Usage from Objective-C source files

Import the global header file using:

```objective-c
#import <SRGUserData/SRGUserData.h>
```

or directly import the module itself:

```objective-c
@import SRGUserData;
```

### Usage from Swift source files

Import the module where needed:

```swift
import SRGUserData
```

### Working with the library

To learn about how the library can be used, have a look at the [getting started guide](GETTING_STARTED.md).

## License

See the [LICENSE](../LICENSE) file for more information.
