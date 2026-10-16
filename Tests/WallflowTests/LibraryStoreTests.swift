import XCTest
@testable import Wallflow

final class LibraryStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"wallpapers":[],"assignments":{}}"#.utf8)
            .write(to: directory.appendingPathComponent("library.json"))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func media(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data([0]).write(to: url)
        return url
    }

    func testSelectingCurrentGlobalWallpaperClearsScreenOverridesAndPersists() throws {
        let store = LibraryStore(directory: directory)
        store.add(urls: [try media("first.png"), try media("second.png")])
        let first = store.wallpapers[0].id
        store.assign(store.wallpapers[1].id, to: "external")
        store.select(first)
        XCTAssertTrue(store.assignments.isEmpty)
        XCTAssertEqual(store.wallpaper(forScreen: "external")?.id, first)
        let restored = LibraryStore(directory: directory)
        XCTAssertTrue(restored.assignments.isEmpty)
        XCTAssertEqual(restored.selectedID, first)
    }

    func testImportDeduplicatesAcrossBatchesAndSymbolicLinks() throws {
        let original = try media("wallpaper.png")
        let link = directory.appendingPathComponent("alias.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        let store = LibraryStore(directory: directory)
        store.add(urls: [original, original, link])
        store.add(urls: [link, original])
        XCTAssertEqual(store.wallpapers.count, 1)
    }

    func testImportRejectsMissingFilesDirectoriesUnsupportedAndRemoteURLs() throws {
        let folder = directory.appendingPathComponent("folder.png")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = LibraryStore(directory: directory)
        store.add(urls: [folder, directory.appendingPathComponent("missing.gif"),
                         try media("notes.txt"), URL(string: "https://example.com/a.png")!])
        XCTAssertTrue(store.wallpapers.isEmpty)
    }

    func testEmptyLibraryStaysEmptyAfterRestart() {
        XCTAssertTrue(LibraryStore(directory: directory).wallpapers.isEmpty)
    }

    func testClearedSelectionStaysClearedAfterRestart() throws {
        let store = LibraryStore(directory: directory)
        store.add(urls: [try media("first.png")])
        store.select(nil)
        let restored = LibraryStore(directory: directory)
        XCTAssertEqual(restored.wallpapers.count, 1)
        XCTAssertNil(restored.selectedID)
    }

    func testRemovingSelectedWallpaperRepairsAssignmentsAndSurvivesRestart() throws {
        let store = LibraryStore(directory: directory)
        store.add(urls: [try media("first.png"), try media("second.png")])
        let removed = store.wallpapers[0].id
        let remaining = store.wallpapers[1].id
        store.assign(removed, to: "external")
        store.remove(ids: [removed])
        let restored = LibraryStore(directory: directory)
        XCTAssertEqual(restored.selectedID, remaining)
        XCTAssertTrue(restored.assignments.isEmpty)
    }

    func testInvalidSelectionAndAssignmentsAreIgnored() throws {
        let store = LibraryStore(directory: directory)
        store.add(urls: [try media("first.png")])
        let selected = store.selectedID
        store.select(UUID())
        store.assign(UUID(), to: "external")
        XCTAssertEqual(store.selectedID, selected)
        XCTAssertTrue(store.assignments.isEmpty)
    }

    func testLegacyLibraryWithoutAssignmentsLoads() throws {
        let wallpaper = Wallpaper(name: "legacy", path: "/tmp/legacy.png", kind: .image)
        let wallpapers = String(decoding: try JSONEncoder().encode([wallpaper]), as: UTF8.self)
        try Data("{\"wallpapers\":\(wallpapers),\"selectedID\":\"\(wallpaper.id)\"}".utf8)
            .write(to: directory.appendingPathComponent("library.json"))
        let store = LibraryStore(directory: directory)
        XCTAssertEqual(store.selectedID, wallpaper.id)
        XCTAssertTrue(store.assignments.isEmpty)
    }

    func testDanglingPersistedSelectionAndAssignmentsRecover() throws {
        let wallpaper = Wallpaper(name: "valid", path: "/tmp/valid.png", kind: .image)
        let wallpapers = String(decoding: try JSONEncoder().encode([wallpaper]), as: UTF8.self)
        let invalidID = UUID()
        try Data("{\"wallpapers\":\(wallpapers),\"selectedID\":\"\(invalidID)\",\"assignments\":{\"external\":\"\(invalidID)\"}}".utf8)
            .write(to: directory.appendingPathComponent("library.json"))
        let store = LibraryStore(directory: directory)
        XCTAssertEqual(store.selectedID, wallpaper.id)
        XCTAssertTrue(store.assignments.isEmpty)
    }
}
