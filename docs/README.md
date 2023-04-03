[![SRG User Data logo](README-images/logo.png)](https://github.com/SRGSSR/srguserdata-apple)

[![GitHub releases](https://img.shields.io/github/v/release/SRGSSR/srguserdata-apple)](https://github.com/SRGSSR/srguserdata-apple/releases) [![platform](https://img.shields.io/badge/platfom-ios%20%7C%20tvos-blue)](https://github.com/SRGSSR/srguserdata-apple) [![SPM compatible](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager) [![GitHub license](https://img.shields.io/github/license/SRGSSR/srguserdata-apple)](https://github.com/SRGSSR/srguserdata-apple/blob/master/LICENSE)

## About

The SRG User Data framework provides easy user data management:

* Playback history.
* Playlists.
* Preferences.

User data storage can be bound to an [SRG Identity](https://github.com/SRGSSR/srgidentity-apple) service, so that logged in users can have their personal data automatically synchronized with their account, and thus available across devices.

## Compatibility

The library is suitable for applications running on iOS 12, tvOS 12 and above. The project is meant to be compiled with the latest Xcode version.

Starting Mac OS Ventura and SPM integration, some Core Data compile errors could appeared. A proposed script `Scripts/coredata-compilation-fix.sh` helps if executed has a build pre action. 

## Contributing

If you want to contribute to the project, have a look at our [contributing guide](CONTRIBUTING.md).

## Integration

The library must be integrated using [Swift Package Manager](https://swift.org/package-manager) directly [within Xcode](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app). You can also declare the library as a dependency of another one directly in the associated `Package.swift` manifest.

## Usage

When you want to use classes or functions provided by the library in your code, you must import it from your source files first. In Objective-C:

```objective-c
@import SRGUserData;
```

or in Swift:

```swift
import SRGUserData
```

### Working with the library

To learn about how the library can be used, have a look at the [getting started guide](GETTING_STARTED.md).

## License

See the [LICENSE](../LICENSE) file for more information.
