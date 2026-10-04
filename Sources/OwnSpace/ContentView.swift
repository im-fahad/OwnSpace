import AppKit
import OwnSpaceCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var category: JunkCategory? = .userCaches
    @State private var confirming = false

    var body: some View {
        NavigationSplitView {
            List(JunkCategory.allCases, selection: $category) { category in
                HStack {
                    Label(category.title, systemImage: category.symbol)
                    Spacer()
                    if model.hasScanned {
                        Text(model.result.size(of: category).bytes)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
            .safeAreaInset(edge: .bottom) { summary }
        } detail: {
            if let category {
                CategoryView(category: category)
            } else {
                ContentUnavailableView("Pick a category", systemImage: "sidebar.left")
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await model.scan() }
                } label: {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    confirming = true
                } label: {
                    Text(model.selection.isEmpty ? "Clean" : "Clean \(model.selectedSize.bytes)")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selection.isEmpty || model.isBusy)
            }
        }
        .confirmationDialog(confirmTitle, isPresented: $confirming) {
            Button("Clean", role: .destructive) { Task { await model.cleanSelected() } }
        } message: {
            Text(confirmMessage)
        }
        .alert(
            "Cleaned",
            isPresented: Binding(get: { model.lastClean != nil }, set: { if !$0 { model.lastClean = nil } }),
            presenting: model.lastClean
        ) { _ in
            Button("OK") {}
        } message: { clean in
            Text(cleanMessage(clean))
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.isBusy {
                ProgressView().controlSize(.small)
            } else if model.hasScanned {
                Text("\(model.result.totalSize.bytes) found").font(.headline)
            }
            if !model.result.unreadable.isEmpty {
                Button("Some folders need Full Disk Access") { openFullDiskAccess() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var confirmTitle: String {
        "Clean \(model.selection.count) item\(model.selection.count == 1 ? "" : "s")?"
    }

    private var confirmMessage: String {
        let permanent = model.selectedItems.contains { $0.category.deletesPermanently }
        var text = "Items move to the Trash, so you can still put them back."
        if permanent { text += " Items already in the Trash are deleted for good." }
        return text
    }

    private func cleanMessage(_ clean: CleanResult) -> String {
        var parts: [String] = []
        if clean.trashed > 0 { parts.append("\(clean.trashed.bytes) moved to the Trash. Empty it to get the space back.") }
        if clean.freed > 0 { parts.append("\(clean.freed.bytes) deleted.") }
        if !clean.failures.isEmpty {
            parts.append("\(clean.failures.count) could not be removed, often because an app has them open.")
        }
        return parts.isEmpty ? "Nothing changed." : parts.joined(separator: "\n")
    }

    private func openFullDiskAccess() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let url = URL(string: pane) { NSWorkspace.shared.open(url) }
    }
}

struct CategoryView: View {
    @Environment(AppModel.self) private var model
    let category: JunkCategory

    var body: some View {
        let items = model.result.items(in: category)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(category.title).font(.title2.bold())
                Text(category.detail).foregroundStyle(.secondary)
            }
            .padding()

            if items.isEmpty {
                ContentUnavailableView(
                    model.hasScanned ? "Nothing to clean" : "Scanning…",
                    systemImage: model.hasScanned ? "checkmark.circle" : "magnifyingglass"
                )
            } else {
                HStack {
                    Toggle("Select all", isOn: Binding(
                        get: { items.allSatisfy { model.selection.contains($0.url) } },
                        set: { model.selectAll(in: category, $0) }
                    ))
                    Spacer()
                    Text("\(items.count) items").foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                List(items) { item in
                    ItemRow(item: item)
                }
            }
        }
    }
}

struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: CleanupItem

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(get: { model.selection.contains(item.url) }, set: { _ in model.toggle(item) }))
                .labelsHidden()
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 20, height: 20)
            VStack(alignment: .leading) {
                Text(item.name).lineLimit(1)
                Text(item.url.deletingLastPathComponent().path(percentEncoded: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(item.size.bytes).monospacedDigit().foregroundStyle(.secondary)
        }
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }
}
