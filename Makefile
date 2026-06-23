.PHONY: build clean run dev generate-project setup

APP_NAME = Conduct
BUILD_DIR = build
SOURCES = $(wildcard Sources/*.swift)
FRAMEWORK_DIR = Frameworks
SWIFT_DEBUG_FLAGS ?= -D DEBUG

# Always resolve compiler + SDK from the active Xcode/developer toolchain
# so the two are guaranteed to match (avoids Swift version mismatch errors).
SWIFTC  = $(shell xcrun --find swiftc)
SDK     = $(shell xcrun --sdk macosx --show-sdk-path)

# Code signing identity. Defaults to the local self-signed "Conduct Dev" cert
# when it is present in the keychain, otherwise falls back to ad-hoc signing ("-")
# so CI runners (which have no signing identity installed) can still build.
# Override for distribution, e.g.:
#   make build-universal CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
CODESIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q "Conduct Dev" && echo "Conduct Dev" || echo "-")

# Build the app using swiftc directly (no Xcode project needed)
build: check-sparkle $(BUILD_DIR)/$(APP_NAME).app

check-sparkle:
	@if [ ! -d "$(FRAMEWORK_DIR)/Sparkle.framework" ]; then \
		echo "Error: Sparkle.framework not found. Run 'make setup' first."; \
		exit 1; \
	fi

setup:
	@chmod +x Scripts/setup-sparkle.sh
	@Scripts/setup-sparkle.sh

$(BUILD_DIR)/$(APP_NAME).app: $(SOURCES) Sources/Info.plist
	@mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS"
	@mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources"
	@mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/Frameworks"
	@cp Sources/Info.plist "$(BUILD_DIR)/$(APP_NAME).app/Contents/Info.plist"
	@echo "APPL????" > "$(BUILD_DIR)/$(APP_NAME).app/Contents/PkgInfo"
	@cp Resources/AppIcon.icns "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/AppIcon.icns"
	@cp Resources/MenuBarIcon.png "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/MenuBarIcon.png"
	@cp Resources/MenuBarIcon@2x.png "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/MenuBarIcon@2x.png"
	@cp docs/icons/*.png "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/"
	@for lproj in Resources/*.lproj; do \
		cp -R "$$lproj" "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/"; \
	done
	@cp -R "$(FRAMEWORK_DIR)/Sparkle.framework" "$(BUILD_DIR)/$(APP_NAME).app/Contents/Frameworks/"
	$(SWIFTC) \
		-target arm64-apple-macos11.0 \
		-sdk $(SDK) \
		-O \
		$(SWIFT_DEBUG_FLAGS) \
		-module-name $(APP_NAME) \
		-emit-executable \
		-o "$(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" \
		-F $(FRAMEWORK_DIR) \
		-framework AppKit \
		-framework Carbon \
		-framework ServiceManagement \
		-framework Sparkle \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks \
		$(SOURCES)
	@find "$(BUILD_DIR)/$(APP_NAME).app" -name "._*" -delete 2>/dev/null || true
	@xattr -cr "$(BUILD_DIR)/$(APP_NAME).app" 2>/dev/null || true; \
		echo "Signing with identity: $(CODESIGN_IDENTITY)"; \
			codesign --force --sign "$(CODESIGN_IDENTITY)" --entitlements Sources/Conduct.entitlements "$(BUILD_DIR)/$(APP_NAME).app"
build-universal: check-sparkle $(SOURCES) Sources/Info.plist
	@mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS"
	@mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources"
	@mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/Frameworks"
	@cp Sources/Info.plist "$(BUILD_DIR)/$(APP_NAME).app/Contents/Info.plist"
	@echo "APPL????" > "$(BUILD_DIR)/$(APP_NAME).app/Contents/PkgInfo"
	@cp Resources/AppIcon.icns "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/AppIcon.icns"
	@cp Resources/MenuBarIcon.png "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/MenuBarIcon.png"
	@cp Resources/MenuBarIcon@2x.png "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/MenuBarIcon@2x.png"
	@cp docs/icons/*.png "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/"
	@for lproj in Resources/*.lproj; do \
		cp -R "$$lproj" "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources/"; \
	done
	@cp -R "$(FRAMEWORK_DIR)/Sparkle.framework" "$(BUILD_DIR)/$(APP_NAME).app/Contents/Frameworks/"
	$(SWIFTC) \
		-target arm64-apple-macos11.0 \
		-sdk $(SDK) \
		-O \
		$(SWIFT_DEBUG_FLAGS) \
		-module-name $(APP_NAME) \
		-emit-executable \
		-o "$(BUILD_DIR)/$(APP_NAME)-arm64" \
		-F $(FRAMEWORK_DIR) \
		-framework AppKit \
		-framework Carbon \
		-framework ServiceManagement \
		-framework Sparkle \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks \
		$(SOURCES)
	$(SWIFTC) \
		-target x86_64-apple-macos11.0 \
		-sdk $(SDK) \
		-O \
		$(SWIFT_DEBUG_FLAGS) \
		-module-name $(APP_NAME) \
		-emit-executable \
		-o "$(BUILD_DIR)/$(APP_NAME)-x86_64" \
		-F $(FRAMEWORK_DIR) \
		-framework AppKit \
		-framework Carbon \
		-framework ServiceManagement \
		-framework Sparkle \
		-Xlinker -rpath -Xlinker @executable_path/../Frameworks \
		$(SOURCES)
	lipo -create \
		"$(BUILD_DIR)/$(APP_NAME)-arm64" \
		"$(BUILD_DIR)/$(APP_NAME)-x86_64" \
		-output "$(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"
	@rm -f "$(BUILD_DIR)/$(APP_NAME)-arm64" "$(BUILD_DIR)/$(APP_NAME)-x86_64"
	@find "$(BUILD_DIR)/$(APP_NAME).app" -name "._*" -delete 2>/dev/null || true
	@xattr -cr "$(BUILD_DIR)/$(APP_NAME).app" 2>/dev/null || true; \
		echo "Signing with identity: $(CODESIGN_IDENTITY)"; \
			codesign --force --sign "$(CODESIGN_IDENTITY)" --entitlements Sources/Conduct.entitlements "$(BUILD_DIR)/$(APP_NAME).app"
generate-project:
	xcodegen generate
	@echo "✓ Generated Conduct.xcodeproj"

run: build
	open "$(BUILD_DIR)/$(APP_NAME).app"

# Dev workflow: build, then launch a FRESH unique copy from /tmp.
# Each run uses a never-before-registered bundle path, which sidesteps the
# menu-bar status-item "height-0" slot poisoning that accumulates when you keep
# relaunching the SAME registered path (build/ or /Applications) over and over.
# This is essentially what Xcode does (it runs from a fresh DerivedData path).
dev: build
	@-pkill -f "/tmp/$(APP_NAME)-dev-" 2>/dev/null; true
	@rm -rf /tmp/$(APP_NAME)-dev-*.app 2>/dev/null; true
	@FRESH="/tmp/$(APP_NAME)-dev-$$(date +%s).app"; \
		cp -R "$(BUILD_DIR)/$(APP_NAME).app" "$$FRESH"; \
		echo "✓ Launching fresh copy: $$FRESH"; \
		open "$$FRESH"

clean:
	rm -rf $(BUILD_DIR)
	rm -rf Conduct.xcodeproj

install: build-universal
	@-pkill -x $(APP_NAME) 2>/dev/null; sleep 0.5
	@rm -rf /Applications/$(APP_NAME).app
	cp -R "$(BUILD_DIR)/$(APP_NAME).app" /Applications/
	@echo "✓ Installed to /Applications/$(APP_NAME).app"
	@open /Applications/$(APP_NAME).app
