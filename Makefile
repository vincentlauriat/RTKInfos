.PHONY: build-cli install-cli clean-cli

build-cli:
	swift build -c release

install-cli: build-cli
	cp .build/arm64-apple-macosx/release/RTKStats /usr/local/bin/rtk-stats
	@echo "rtk-stats installé dans /usr/local/bin/"

clean-cli:
	swift package clean
