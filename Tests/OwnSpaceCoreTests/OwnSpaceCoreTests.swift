import Foundation
import Testing
@testable import OwnSpaceCore

/// A throwaway home folder, so tests never touch the real one.
private func makeHome() throws -> URL {
    let home = FileManager.default.temporaryDirectory.appending(path: "ownspace-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    return home
}

private func write(_ bytes: Int, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(count: bytes).write(to: url)
}

@Test func scanListsChildrenWithSizesLargestFirst() async throws {
    let home = try makeHome()
    defer { try? FileManager.default.removeItem(at: home) }
    try write(100_000, to: home.appending(path: "Library/Caches/com.small.app/a"))
    try write(900_000, to: home.appending(path: "Library/Caches/com.big.app/nested/b"))
    try write(10, to: home.appending(path: "Library/Caches/.DS_Store"))
    try write(50_000, to: home.appending(path: "Library/Caches/com.apple.Music/c"))

    let result = await Scanner.scan(home: home, categories: [.userCaches])

    #expect(result.items.map(\.name) == ["com.big.app", "com.small.app"])
    #expect(result.items[0].size >= 900_000)
    #expect(result.size(of: .userCaches) == result.totalSize)
}

@Test func missingFoldersAreSkippedQuietly() async throws {
    let home = try makeHome()
    defer { try? FileManager.default.removeItem(at: home) }

    let result = await Scanner.scan(home: home)

    #expect(result.items.isEmpty)
    #expect(result.unreadable.isEmpty)
}

@Test func cleanerDeletesTrashItemsAndRefusesOutsiders() throws {
    let home = try makeHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let inTrash = home.appending(path: ".Trash/old.zip")
    let outside = home.appending(path: "Documents/keep.txt")
    try write(4096, to: inTrash)
    try write(4096, to: outside)

    let result = Cleaner.clean([
        CleanupItem(url: inTrash, category: .trash, size: 4096),
        CleanupItem(url: outside, category: .trash, size: 4096),
        CleanupItem(url: home.appending(path: ".Trash/../Documents/keep.txt"), category: .trash, size: 4096),
        CleanupItem(url: home.appending(path: ".Trash"), category: .trash, size: 4096),
    ], home: home)

    #expect(!FileManager.default.fileExists(atPath: inTrash.path))
    #expect(FileManager.default.fileExists(atPath: outside.path))
    #expect(FileManager.default.fileExists(atPath: home.appending(path: ".Trash").path))
    #expect(result.freed == 4096)
    #expect(result.failures.count == 3)
}
