import Foundation

/// One removable file or folder.
public struct CleanupItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let category: JunkCategory
    public let size: Int64

    public var name: String { url.lastPathComponent }
}

/// What a scan found, plus the folders it could not read.
public struct ScanResult: Sendable {
    public var items: [CleanupItem] = []
    /// Folders that exist but were not readable, usually because Full Disk Access is off.
    public var unreadable: [URL] = []

    public init(items: [CleanupItem] = [], unreadable: [URL] = []) {
        self.items = items
        self.unreadable = unreadable
    }

    public func items(in category: JunkCategory) -> [CleanupItem] {
        items.filter { $0.category == category }
    }

    public func size(of category: JunkCategory) -> Int64 {
        items(in: category).reduce(0) { $0 + $1.size }
    }

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

public enum Scanner {
    /// Lists every child of each category's folders with its size on disk, largest first.
    public static func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        categories: [JunkCategory] = JunkCategory.allCases
    ) async -> ScanResult {
        var candidates: [(URL, JunkCategory)] = []
        var unreadable: [URL] = []
        let fm = FileManager.default

        for category in categories {
            for folder in category.folders {
                let dir = home.appending(path: folder, directoryHint: .isDirectory)
                guard fm.fileExists(atPath: dir.path) else { continue }
                do {
                    let children = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                    for child in children where !category.skips(child.lastPathComponent) {
                        candidates.append((child, category))
                    }
                } catch {
                    unreadable.append(dir)
                }
            }
        }

        let items = await withTaskGroup(of: CleanupItem?.self) { group in
            for (url, category) in candidates {
                group.addTask {
                    let size = allocatedSize(of: url)
                    return size > 0 ? CleanupItem(url: url, category: category, size: size) : nil
                }
            }
            var found: [CleanupItem] = []
            for await item in group {
                if let item { found.append(item) }
            }
            return found
        }

        return ScanResult(items: items.sorted { $0.size > $1.size }, unreadable: unreadable)
    }

    /// Bytes the file, or everything under the folder, takes on disk. Unreadable parts count as zero.
    public static func allocatedSize(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

        func size(_ values: URLResourceValues?) -> Int64 {
            guard let values, values.isRegularFile == true else { return 0 }
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        let own = try? url.resourceValues(forKeys: Set(keys))
        if own?.isRegularFile == true { return size(own) }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += size(try? file.resourceValues(forKeys: Set(keys)))
        }
        return total
    }
}
