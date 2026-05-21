PROFDATA = .build/debug/codecov/default.profdata
BIN = .build/debug/SwiftDependencyUpdaterPackageTests.xctest/Contents/MacOS/SwiftDependencyUpdaterPackageTests
IGNORE = -ignore-filename-regex '.build/'

.PHONY: test

test:
	swift test --enable-code-coverage
	@xcrun llvm-cov report "$(BIN)" -instr-profile "$(PROFDATA)" $(IGNORE)
