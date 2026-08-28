PROJECT=GitHubExplorer.xcodeproj
SCHEME=GitHubExplorer
DESTINATION=platform=iOS Simulator,OS=latest,name=iPhone 16 Pro

.PHONY: test build

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk iphonesimulator -destination '$(DESTINATION)' build CODE_SIGNING_ALLOWED=NO

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk iphonesimulator -destination '$(DESTINATION)' test CODE_SIGNING_ALLOWED=NO
