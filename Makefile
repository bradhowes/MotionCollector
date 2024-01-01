PLATFORM_IOS = iOS Simulator,name=iPhone SE (3rd generation)

default: percentage

test-ios:
	xcodebuild clean \
		-scheme MotionCollector \
		-derivedDataPath ".DerivedData-ios" \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme MotionCollector \
		-derivedDataPath ".DerivedData-ios" \
		-destination platform="$(PLATFORM_IOS)" \
		-enableCodeCoverage YES

COV = xcrun xccov view --report --only-targets

coverage: test-ios
	$(COV) .DerivedData-ios/Logs/Test/*.xcresult > coverage.txt
	@cat coverage.txt

PATTERN = MotionCollector.app

percentage: coverage
	awk '/$(PATTERN)/ {s+=$$4;++c} END {print s/c;}' < coverage.txt > percentage.txt
	@cat percentage.txt

.PHONY: build test coverage percentage clean
