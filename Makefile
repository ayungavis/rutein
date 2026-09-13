SCHEME     = RuteinApp
APP_DIR    = apps/ios/RuteinApp
PROJECT    = $(APP_DIR)/RuteinApp.xcodeproj
PACKAGE    = $(APP_DIR)/RuteinKit
SPEC       = project.yaml
DEST       = platform=iOS Simulator,name=iPhone 17 Pro
BUILD_LOG  = /tmp/rutein-build.log
ARCHIVE    = /tmp/rutein/RuteinApp.xcarchive
ARCH_LOG   = /tmp/rutein-archive.log
TEST_FLAGS ?=

.DEFAULT_GOAL := help

.PHONY: help hooks ios-generate ios-format ios-lint ios-previews ios-tokens ios-tokens-check ios-test ios-build ios-run ios-archive ios-validate

help:
	@echo "Rutein — GPX route preparation for trail runners."
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

ios-lint: ios-previews ios-tokens-check ## SwiftLint in strict mode, plus the preview and token checks
	swiftlint --strict

ios-previews: ## Every *View.swift must declare a #Preview
	@missing=$$(grep -L '#Preview' $$(find $(PACKAGE)/Sources -name '*View.swift') 2>/dev/null); \
	if [ -n "$$missing" ]; then \
		echo "Views without a #Preview:"; \
		echo "$$missing" | sed 's|^|  |'; \
		echo "Every SwiftUI view declares one. See CLAUDE.md > Architecture."; \
		exit 1; \
	fi; \
	echo "previews OK — every *View.swift declares a #Preview"

ios-tokens: ## Regenerate Colors.xcassets from docs/design/tokens
	@python3 tools/generate-colors.py

ios-tokens-check: ## Fail if Colors.xcassets drifted from docs/design/tokens
	@python3 tools/generate-colors.py --check

ios-test: ## Unit tests via swift test — no simulator needed
	swift test --package-path $(PACKAGE) $(TEST_FLAGS)

ios-build: ios-generate ## Build for the iPhone simulator
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' build > $(BUILD_LOG) 2>&1 \
		&& grep -E '^\*\* BUILD' $(BUILD_LOG) \
		|| (tail -30 $(BUILD_LOG); exit 1)

ios-run: ios-build ## Build, install, and launch on the booted simulator
	@SETTINGS=$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -showBuildSettings 2>/dev/null); \
	APP=$$(echo "$$SETTINGS" | awk '$$1 == "BUILT_PRODUCTS_DIR" { print $$3; exit }'); \
	BUNDLE=$$(echo "$$SETTINGS" | awk '$$1 == "PRODUCT_BUNDLE_IDENTIFIER" { print $$3; exit }'); \
	xcrun simctl install booted "$$APP/$(SCHEME).app" && \
	xcrun simctl launch booted "$$BUNDLE"

ios-archive: ios-generate ## Local Release archive — escape hatch when CI is red
	@rm -rf $(ARCHIVE)
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'generic/platform=iOS' -configuration Release \
		-archivePath $(ARCHIVE) -allowProvisioningUpdates archive > $(ARCH_LOG) 2>&1 \
		&& grep -E '^\*\* ARCHIVE' $(ARCH_LOG) \
		|| (tail -40 $(ARCH_LOG); exit 1)
	@echo "archive at $(ARCHIVE) — open Xcode > Window > Organizer to distribute"
	@echo "normal path is a push to main; see .github/workflows/testflight.yml"

ios-validate: ios-format ios-lint ios-test ios-build ## format → lint → test → build
	@echo "iOS OK — format, lint, test, build all green"
