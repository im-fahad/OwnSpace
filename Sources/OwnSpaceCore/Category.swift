import Foundation

/// A kind of junk, and where it lives under the home folder.
public enum JunkCategory: String, CaseIterable, Identifiable, Sendable {
    case userCaches
    case logs
    case xcode
    case simulators
    case packageCaches
    case trash

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .userCaches: "App caches"
        case .logs: "Logs"
        case .xcode: "Xcode"
        case .simulators: "Simulators"
        case .packageCaches: "Package caches"
        case .trash: "Trash"
        }
    }

    public var symbol: String {
        switch self {
        case .userCaches: "shippingbox"
        case .logs: "doc.text"
        case .xcode: "hammer"
        case .simulators: "iphone"
        case .packageCaches: "cube.box"
        case .trash: "trash"
        }
    }

    public var detail: String {
        switch self {
        case .userCaches: "Apps rebuild these when needed. Quit an app before clearing its cache."
        case .logs: "Old diagnostic logs from apps and the system."
        case .xcode: "Build products, archives and device symbols. Xcode recreates what it needs."
        case .simulators: "Simulator caches. Your simulators and their data are left alone."
        case .packageCaches: "Downloaded packages from npm, pnpm, Gradle and others. They download again on demand."
        case .trash: "Files already in the Trash. Clearing these deletes them for good."
        }
    }

    /// Folders whose children are listed as separate items, relative to the home folder.
    public var folders: [String] {
        switch self {
        case .userCaches: ["Library/Caches"]
        case .logs: ["Library/Logs"]
        case .xcode: [
            "Library/Developer/Xcode/DerivedData",
            "Library/Developer/Xcode/Archives",
            "Library/Developer/Xcode/iOS DeviceSupport",
            "Library/Developer/Xcode/watchOS DeviceSupport",
            "Library/Developer/Xcode/Products",
        ]
        case .simulators: ["Library/Developer/CoreSimulator/Caches"]
        case .packageCaches: [
            ".npm/_cacache",
            "Library/pnpm/store",
            ".gradle/caches",
            ".cache",
        ]
        case .trash: [".Trash"]
        }
    }

    /// Children left out of the listing. Apple's own caches are managed by macOS, and reading many of
    /// them sets off privacy prompts (Music, Photos, Safari), so OwnSpace does not touch them.
    public func skips(_ name: String) -> Bool {
        if name == ".DS_Store" { return true }
        switch self {
        case .userCaches, .logs: return name.hasPrefix("com.apple.")
        default: return false
        }
    }

    /// Trash items are already discarded, so they are deleted rather than moved back into the Trash.
    public var deletesPermanently: Bool { self == .trash }
}
