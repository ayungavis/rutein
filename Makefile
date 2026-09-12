SCHEME     = RuteinApp
APP_DIR    = apps/ios/RuteinApp
PROJECT    = $(APP_DIR)/RuteinApp.xcodeproj
PACKAGE    = $(APP_DIR)/RuteinKit
SPEC       = project.yaml
DEST       = platform=iOS Simulator,name=iPhone 17 Pro
BUILD_LOG  = /tmp/rutein-build.log
TEST_FLAGS ?=

.DEFAULT_GOAL := help

.PHONY: help hooks ios-generate ios-format ios-lint ios-test ios-build ios-run ios-validate

help:
	@echo "Rutein — GPX route preparation for trail runners. iOS only, no backend."
	@echo
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

hooks:
	@test -d .git || (echo "not a git repository yet — run 'git init' first" && exit 1)
	@mkdir -p .git/hooks
	@cp .githooks/* .git/hooks/
	@chmod +x .git/hooks/*
	@echo "hooks installed into .git/hooks"

# ------------------------------------------------------------------- iOS

ios-generate: ## Regenerate RuteinApp.xcodeproj from project.yaml
	cd $(APP_DIR) && xcodegen generate --spec $(SPEC)

ios-format: ## SwiftFormat the whole repo
	swiftformat .

ios-lint: ## SwiftLint in strict mode
	swiftlint --strict

ios-test: ## Unit tests via swift test — no simulator needed
	swift test --package-path $(PACKAGE) $(TEST_FLAGS)

# xcodebuild output is huge — log it, print the tail only when the build fails.
ios-build: ios-generate ## Build for the iPhone simulator
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' build > $(BUILD_LOG) 2>&1 \
		&& grep -E '^\*\* BUILD' $(BUILD_LOG) \
		|| (tail -30 $(BUILD_LOG); exit 1)

# Bundle id is read back from the build settings rather than repeated here, so
# it cannot drift from project.yaml.
ios-run: ios-build ## Build, install, and launch on the booted simulator
	@SETTINGS=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -showBuildSettings 2>/dev/null); \
	APP=$$(echo "$$SETTINGS" | awk '$$1 == "BUILT_PRODUCTS_DIR" { print $$3; exit }'); \
	BUNDLE=$$(echo "$$SETTINGS" | awk '$$1 == "PRODUCT_BUNDLE_IDENTIFIER" { print $$3; exit }'); \
	xcrun simctl install booted "$$APP/$(SCHEME).app" && \
	xcrun simctl launch booted "$$BUNDLE"

ios-validate: ios-format ios-lint ios-test ios-build ## format → lint → test → build
	@echo "iOS OK — format, lint, test, build all green"
