SWIFT_FORMAT ?= swift-format

.PHONY: format lint test build resolve clean

format:
	@$(SWIFT_FORMAT) format -i -r Package.swift Sources Tests Example/Package.swift Example/Sources

lint:
	@$(SWIFT_FORMAT) lint --strict -r Package.swift Sources Tests Example/Package.swift Example/Sources

build:
	swift build

test:
	swift test -v

resolve:
	swift package resolve

clean:
	swift package clean
