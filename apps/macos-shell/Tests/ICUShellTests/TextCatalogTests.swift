import Foundation
import XCTest
@testable import ICUShell

final class TextCatalogTests: XCTestCase {
    func testCatalogReturnsBaseValueWhenNoOverrideExists() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let baseURL = tempDirectory.appendingPathComponent("base.json", isDirectory: false)
        try writeJSON(
            """
            {
              "common": {
                "apply_button": "应用"
              }
            }
            """,
            to: baseURL
        )

        let catalog = try TextCatalog(baseURL: baseURL, overrideURL: nil)

        XCTAssertEqual(catalog.text(.commonApplyButton, fallback: "fallback"), "应用")
    }

    func testCatalogUsesOverrideValueWhenMatchingKeyExists() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let baseURL = tempDirectory.appendingPathComponent("base.json", isDirectory: false)
        let overrideURL = tempDirectory.appendingPathComponent("active.json", isDirectory: false)
        try writeJSON(
            """
            {
              "theme_studio": {
                "tab_title": "主题风格"
              }
            }
            """,
            to: baseURL
        )
        try writeJSON(
            """
            {
              "theme_studio": {
                "tab_title": "像素主题"
              }
            }
            """,
            to: overrideURL
        )

        let catalog = try TextCatalog(baseURL: baseURL, overrideURL: overrideURL)

        XCTAssertEqual(catalog.text(.themeStudioTabTitle, fallback: "fallback"), "像素主题")
    }

    func testCatalogFallsBackToBaseWhenOverrideDoesNotProvideTheKey() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let baseURL = tempDirectory.appendingPathComponent("base.json", isDirectory: false)
        let overrideURL = tempDirectory.appendingPathComponent("active.json", isDirectory: false)
        try writeJSON(
            """
            {
              "common": {
                "close_button": "关闭"
              }
            }
            """,
            to: baseURL
        )
        try writeJSON(
            """
            {
              "theme_studio": {
                "tab_title": "主题风格"
              }
            }
            """,
            to: overrideURL
        )

        let catalog = try TextCatalog(baseURL: baseURL, overrideURL: overrideURL)

        XCTAssertEqual(catalog.text(.commonCloseButton, fallback: "fallback"), "关闭")
    }

    func testCatalogFallsBackToCallerDefaultWhenKeyIsMissingEverywhere() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let baseURL = tempDirectory.appendingPathComponent("base.json", isDirectory: false)
        try writeJSON("{}", to: baseURL)

        let catalog = try TextCatalog(baseURL: baseURL, overrideURL: nil)

        XCTAssertEqual(
            catalog.text(.speechStudioBubblePreviewTitle, fallback: "桌宠对话气泡预览"),
            "桌宠对话气泡预览"
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeJSON(_ content: String, to url: URL) throws {
        try content.data(using: .utf8)?.write(to: url)
    }
}
