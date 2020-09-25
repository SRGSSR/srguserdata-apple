About the Data directory:
-------------------------

Each test data set should have been a folder reference (blue folder) instead of a group (yellow folder). Due to
an Xcode bug, though, we cannot have side-by-side Package and xcodeproj belonging to the package directory, with
the project containing folder references. This leads to a crash, probably because of a recursive call never ending.

To workaround this issue (and to keep the test as separate directories):

- The data set folders have been added visually but not to any target.
- They are copied in the final product with a copy files script phase instead.

This issue will be reported to Apple but, in the meantime, this is the easiest workaround.
