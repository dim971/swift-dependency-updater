import XCTest
@testable import DependencyUpdaterCore

final class DependencyUpdaterToolTests: XCTestCase {

    private let tool = DependencyUpdaterTool()

    // MARK: - extractPackageName

    func testExtractPackageName_withGitSuffix() {
        let result = tool.extractPackageName(from: "https://github.com/firebase/firebase-ios-sdk.git")
        XCTAssertEqual(result, "firebase-ios-sdk")
    }

    func testExtractPackageName_withoutGitSuffix() {
        let result = tool.extractPackageName(from: "https://github.com/Alamofire/Alamofire")
        XCTAssertEqual(result, "Alamofire")
    }

    func testExtractPackageName_emptyString() {
        let result = tool.extractPackageName(from: "")
        XCTAssertNil(result)
    }

    func testExtractPackageName_trailingSlash() {
        // split(separator:) discards trailing empty segments, so the last component is "repo"
        let result = tool.extractPackageName(from: "https://github.com/repo/")
        XCTAssertEqual(result, "repo")
    }

    // MARK: - findClosingParenthesis

    func testFindClosingParenthesis_simple() {
        let content = "(abc)"
        let start = content.index(after: content.startIndex) // after '('
        let result = tool.findClosingParenthesis(in: content, from: start)
        XCTAssertNotNil(result)
        XCTAssertEqual(content[result!], ")")
        XCTAssertEqual(result, content.index(before: content.endIndex))
    }

    func testFindClosingParenthesis_nested() {
        let content = "(a(b)c)"
        let start = content.index(after: content.startIndex)
        let result = tool.findClosingParenthesis(in: content, from: start)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, content.index(before: content.endIndex))
    }

    func testFindClosingParenthesis_stringLiteral() {
        let content = #"("a(b)")"#
        let start = content.index(after: content.startIndex)
        let result = tool.findClosingParenthesis(in: content, from: start)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, content.index(before: content.endIndex))
    }

    func testFindClosingParenthesis_unmatched() {
        let content = "(abc"
        let start = content.index(after: content.startIndex)
        let result = tool.findClosingParenthesis(in: content, from: start)
        XCTAssertNil(result)
    }

    // MARK: - updatePackageContent

    func testUpdatePackageContent_singleLineExact() {
        let content = """
        .package(url: "https://github.com/jpsim/Yams.git", exact: "5.0.0")
        """
        let deps = ["Yams": "6.0.0"]
        let result = tool.updatePackageContent(content, with: deps)
        XCTAssertTrue(result.contains(#"exact: "6.0.0""#))
        XCTAssertFalse(result.contains(#"exact: "5.0.0""#))
    }

    func testUpdatePackageContent_multiLine() {
        let content = """
        .package(
            url: "https://github.com/jpsim/Yams.git",
            exact: "5.0.0"
        )
        """
        let deps = ["Yams": "6.0.0"]
        let result = tool.updatePackageContent(content, with: deps)
        XCTAssertTrue(result.contains(#"exact: "6.0.0""#))
    }

    func testUpdatePackageContent_urlNotInDeps() {
        let content = """
        .package(url: "https://github.com/jpsim/Yams.git", exact: "5.0.0")
        """
        let deps = ["SomethingElse": "1.0.0"]
        let result = tool.updatePackageContent(content, with: deps)
        XCTAssertEqual(result, content)
    }

    func testUpdatePackageContent_pathPackageIgnored() {
        let content = """
        .package(path: "../MyLocalPackage")
        """
        let deps = ["MyLocalPackage": "1.0.0"]
        let result = tool.updatePackageContent(content, with: deps)
        XCTAssertEqual(result, content)
    }

    func testUpdatePackageContent_fromVersionIgnored() {
        let content = """
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
        """
        let deps = ["Yams": "6.0.0"]
        let result = tool.updatePackageContent(content, with: deps)
        XCTAssertEqual(result, content, "Packages using 'from:' instead of 'exact:' should not be updated")
    }

    func testUpdatePackageContent_multipleDeps() {
        let content = """
        .package(url: "https://github.com/jpsim/Yams.git", exact: "5.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.6.0"),
        """
        let deps = ["Yams": "6.0.0", "Alamofire": "5.9.0"]
        let result = tool.updatePackageContent(content, with: deps)
        XCTAssertTrue(result.contains(#"exact: "6.0.0""#))
        XCTAssertTrue(result.contains(#"exact: "5.9.0""#))
        XCTAssertFalse(result.contains(#"exact: "5.0.0""#))
        XCTAssertFalse(result.contains(#"exact: "5.6.0""#))
    }

    // MARK: - replacingPBXVersion

    func testReplacingPBXVersion_quotedValue() {
        let line = #"                version = "1.0.0""#
        let result = tool.replacingPBXVersion(in: line, key: "version", with: "2.0.0")
        XCTAssertEqual(result, #"                version = "2.0.0""#)
    }

    func testReplacingPBXVersion_unquotedValue() {
        let line = "                version = 1.0.0;"
        let result = tool.replacingPBXVersion(in: line, key: "version", with: "2.0.0")
        XCTAssertEqual(result, "                version = 2.0.0;")
    }

    func testReplacingPBXVersion_noMatch() {
        let line = "                name = SomePackage;"
        let result = tool.replacingPBXVersion(in: line, key: "version", with: "2.0.0")
        XCTAssertEqual(result, line)
    }

    // MARK: - updatePBXProjContent

    func testUpdatePBXProjContent_updatesVersionAndMinimumVersion() {
        let content = """
        /* XCRemoteSwiftPackageReference "Yams" */ = {
            isa = XCRemoteSwiftPackageReference;
            repositoryURL = "https://github.com/jpsim/Yams.git";
            requirement = {
                kind = exactVersion;
                version = 5.0.0;
            };
        };
        """
        let deps = ["Yams": "6.0.0"]
        let result = tool.updatePBXProjContent(content, with: deps)
        XCTAssertTrue(result.contains("version = 6.0.0;"))
        XCTAssertFalse(result.contains("version = 5.0.0;"))
    }

    func testUpdatePBXProjContent_depNotInDict() {
        let content = """
        /* XCRemoteSwiftPackageReference "Yams" */ = {
            isa = XCRemoteSwiftPackageReference;
            repositoryURL = "https://github.com/jpsim/Yams.git";
            requirement = {
                kind = exactVersion;
                version = 5.0.0;
            };
        };
        """
        let deps = ["SomethingElse": "1.0.0"]
        let result = tool.updatePBXProjContent(content, with: deps)
        XCTAssertEqual(result, content)
    }
}
