fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios tests

```sh
[bundle exec] fastlane ios tests
```



### ios ci_tests

```sh
[bundle exec] fastlane ios ci_tests
```



### ios build_ipa

```sh
[bundle exec] fastlane ios build_ipa
```



### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```



### ios whats_new

```sh
[bundle exec] fastlane ios whats_new
```

Set App Store 'What's New' from fastlane/whatsnew/<version>[.txt]

### ios prepare_app_store_submission

```sh
[bundle exec] fastlane ios prepare_app_store_submission
```

Prepare ASC submission with existing TestFlight build (no submit)

### ios submit_for_review_manual

```sh
[bundle exec] fastlane ios submit_for_review_manual
```

Submit prepared version for review (no auto-release)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
