import Foundation
import Observation
import OwnSpaceCore

@MainActor @Observable
final class AppModel {
    private(set) var result = ScanResult()
    private(set) var isBusy = false
    private(set) var hasScanned = false
    var selection: Set<URL> = []
    var lastClean: CleanResult?

    func scan() async {
        isBusy = true
        result = await Scanner.scan()
        // Keep only selections that still exist after the rescan.
        selection = selection.intersection(result.items.map(\.url))
        hasScanned = true
        isBusy = false
    }

    var selectedItems: [CleanupItem] { result.items.filter { selection.contains($0.url) } }
    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }

    func toggle(_ item: CleanupItem) {
        if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
    }

    func selectAll(in category: JunkCategory, _ on: Bool) {
        let urls = result.items(in: category).map(\.url)
        if on { selection.formUnion(urls) } else { selection.subtract(urls) }
    }

    func cleanSelected() async {
        let items = selectedItems
        isBusy = true
        lastClean = await Task.detached { Cleaner.clean(items) }.value
        selection.removeAll()
        isBusy = false
        await scan()
    }
}

extension Int64 {
    var bytes: String { ByteCountFormatter.string(fromByteCount: self, countStyle: .file) }
}
