SCHEME     = RuteinApp
APP_DIR    = apps/ios/RuteinApp
PROJECT    = $(APP_DIR)/RuteinApp.xcodeproj
PACKAGE    = $(APP_DIR)/RuteinKit
SPEC       = project.yaml
DEST       = generic/platform=iOS Simulator
BUILD_LOG  = /tmp/rutein-build.log
ARCHIVE    = /tmp/rutein/RuteinApp.xcarchive
ARCH_LOG   = /tmp/rutein-archive.log
TEST_FLAGS ?=

.DEFAULT_GOAL := help

.PHONY: help hooks ios-generate ios-format ios-lint ios-previews ios-location-check ios-concurrency-check ios-tokens ios-tokens-check ios-test ios-build ios-run ios-archive ios-validate

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

ios-lint: ios-previews ios-location-check ios-concurrency-check ios-tokens-check ## SwiftLint in strict mode, plus the preview, location, concurrency and token checks
	swiftlint --strict --no-cache

ios-previews: ## Every *View.swift must declare a #Preview
	@missing=$$(grep -L '#Preview' $$(find $(PACKAGE)/Sources -name '*View.swift') 2>/dev/null); \
	if [ -n "$$missing" ]; then \
		echo "Views without a #Preview:"; \
		echo "$$missing" | sed 's|^|  |'; \
		echo "Every SwiftUI view declares one. See CLAUDE.md > Architecture."; \
		exit 1; \
	fi; \
	echo "previews OK — every *View.swift declares a #Preview"

ios-location-check: ## PRD section 6 FR-03 — viewing a route never asks for location
	@hits=$$(grep -rlE 'MapUserLocationButton|CLLocationManager|CLServiceSession|CLBackgroundActivitySession|requestWhenInUseAuthorization|requestAlwaysAuthorization|CLLocationUpdate' \
		$(PACKAGE)/Sources $(APP_DIR)/RuteinApp 2>/dev/null; \
		grep -lE 'NSLocation[A-Za-z]*UsageDescription' $(APP_DIR)/$(SPEC) $(APP_DIR)/RuteinApp/Info.plist 2>/dev/null); \
	if [ -n "$$hits" ]; then \
		echo "Location authorization reached these files:"; \
		echo "$$hits" | sed 's|^|  |'; \
		echo "FR-03 forbids requesting location to view an imported route."; \
		exit 1; \
	fi; \
	echo "location OK — nothing asks for location authorization"

ios-concurrency-check: ## PRD section 9 — parsing and geometry stay off the main actor
	@for symbol in "GPXParser.parse:Core/Utilities/GPXParser.swift" \
		"RouteAnalyzer.analyse:Core/Utilities/RouteAnalyzer.swift"; do \
		file=$(PACKAGE)/Sources/RuteinKit/$${symbol#*:}; \
		if ! grep -B2 -E 'static func (parse|analyse)\(' $$file | grep -q '@concurrent'; then \
			echo "$${symbol%%:*} is missing @concurrent."; \
			echo "Since SE-0461 a plain nonisolated async function runs on the caller's actor,"; \
			echo "which puts this work back on the main actor. See PRD section 9."; \
			exit 1; \
		fi; \
	done; \
	echo "concurrency OK — parsing and analysis carry @concurrent"

ios-tokens: ## Regenerate Colors.xcassets from the Figma varzip exports
	@python3 tools/generate-tokens.py

ios-tokens-check: ## Fail if colours, spacing, radius or fonts drifted from the tokens
	@python3 tools/generate-tokens.py --check

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
