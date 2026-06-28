.PHONY: build-cli install-cli clean-cli build-debug run-debug clean-app

# --- CLI (RTKStats) ---

build-cli:
	swift build -c release

install-cli: build-cli
	sudo cp .build/arm64-apple-macosx/release/RTKStats /usr/local/bin/rtk-stats
	@echo "rtk-stats installé dans /usr/local/bin/"

clean-cli:
	swift package clean

# --- App macOS (RTKInfos) ---

# Variables de build
APP            := RTKInfos
DERIVED        := build/DerivedData
BUILT_APP      := $(DERIVED)/Build/Products/Debug/$(APP).app
# Staged OUTSIDE the repo: ~/Documents is a macOS-protected location that
# re-applies com.apple.provenance xattrs, which makes codesign --verify fail
# ("resource fork ... detritus not allowed"). $(TMPDIR) (/var/folders/…) is not
# protected, so the ad-hoc signature verifies there.
STAGED_APP     := $(TMPDIR)$(APP)-debug.app

# Build Debug sans signature.
# macOS Sequoia ajoute des xattr com.apple.provenance/macl protégés par le kernel
# que codesign rejette ("resource fork, Finder information, or similar detritus").
# On désactive donc la signature au build (CODE_SIGNING_ALLOWED=NO), puis on
# nettoie et on signe en ad-hoc dans run-debug (même approche que scripts/build-release.sh).
build-debug:
	xcodegen generate
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration Debug \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO build
	@git checkout -- Info.plist 2>/dev/null || true

# Stage hors zone protégée ($(TMPDIR)), nettoie les xattr, signe en ad-hoc,
# puis lance l'app.
run-debug: build-debug
	rm -rf "$(STAGED_APP)"
	ditto "$(BUILT_APP)" "$(STAGED_APP)"
	xattr -cr "$(STAGED_APP)" 2>/dev/null || true
	codesign --force --deep --sign - "$(STAGED_APP)"
	codesign --verify --deep --strict "$(STAGED_APP)" && echo "✓ signature ad-hoc OK"
	open "$(STAGED_APP)"
	@echo "$(APP) lancé (barre de menus)"

clean-app:
	rm -rf "$(DERIVED)" "$(STAGED_APP)"
