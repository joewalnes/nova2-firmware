# You need XCode, XCode command line tools and xctool installed.
# See: https://github.com/facebook/xctool

all: sdk-test
.PHONY: all

# Compile only (but don't fire up simulator to run tests)
build:
	xctool -project NovaSDK.xcodeproj -scheme NovaSDKTests build-tests
.PHONY: build

# Build SDK and run unit tests
sdk-test:
	xctool -project NovaSDK.xcodeproj -scheme NovaSDKTests -sdk iphonesimulator test
.PHONY: sdk-test

