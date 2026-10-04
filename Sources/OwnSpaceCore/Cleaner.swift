import Foundation

public struct CleanFailure: Sendable {
    public let url: URL
    public let message: String
}

public struct CleanResult: Sendable {
    public var freed: Int64 = 0
    /// Bytes moved to the Trash: they free up only once the Trash is emptied.
    public var trashed: Int64 = 0
    public var failures: [CleanFailure] = []
}

public enum Cleaner {
    /// Moves items to the Trash, except ones already in it, which are deleted.
    /// Refuses anything outside the category folders, so a bad item can never reach other files.
    public static func clean(
        _ items: [CleanupItem],
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> CleanResult {
        let fm = FileManager.default
        var result = CleanResult()

        for item in items {
            guard isInsideCategoryFolder(item, home: home) else {
                result.failures.append(CleanFailure(url: item.url, message: "Outside the folders OwnSpace cleans"))
                continue
            }
            do {
                if item.category.deletesPermanently {
                    try fm.removeItem(at: item.url)
                    result.freed += item.size
                } else {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    result.trashed += item.size
                }
            } catch {
                result.failures.append(CleanFailure(url: item.url, message: error.localizedDescription))
            }
        }
        return result
    }

    static func isInsideCategoryFolder(_ item: CleanupItem, home: URL) -> Bool {
        let path = item.url.standardizedFileURL.path
        return item.category.folders.contains { folder in
            let dir = home.appending(path: folder, directoryHint: .isDirectory).standardizedFileURL.path
            let prefix = dir.hasSuffix("/") ? dir : dir + "/"
            return path.hasPrefix(prefix) && path.count > prefix.count
        }
    }
}
