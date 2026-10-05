import AppKit
import OwnSpaceCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var category: JunkCategory? = .userCaches
    @State private var confirming = false
    /// Collapsed, the sidebar keeps its icons instead of hiding.
    @AppStorage("sidebarCompact") private var compact = false
    @State private var visibility: NavigationSplitViewVisibility = .all
    /// The window restores a narrow sidebar as hidden at launch; that is not the user clicking.
    @State private var launched = false

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            List(JunkCategory.allCases, selection: $category) { category in
                row(category)
                    .tag(category)
            }
            .safeAreaInset(edge: .bottom) { summary }
            // The system button no longer fits beside the window controls once the sidebar is icons only.
            .toolbar(removing: compact ? .sidebarToggle : nil)
            .navigationSplitViewColumnWidth(min: compact ? 64 : 250, ideal: compact ? 64 : 260, max: compact ? 64 : 320)
        } detail: {
            if let category {
                CategoryView(category: category, confirming: $confirming)
            } else {
                ContentUnavailableView("Pick a category", systemImage: "sidebar.left")
            }
        }
        // The sidebar button and ⌃⌘S would hide the sidebar; switch between icons and full width instead.
        .onChange(of: visibility) { _, newValue in
            guard newValue == .detailOnly else { return }
            visibility = .all
            guard launched else { return }
            withAnimation(.smooth) { compact.toggle() }
        }
        .task {
            try? await Task.sleep(for: .seconds(1))
            launched = true
        }
        .toolbar {
            if compact {
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation(.smooth) { compact = false }
                    } label: {
                        Label("Show Sidebar Titles", systemImage: "sidebar.left")
                    }
                    .help("Expand sidebar (⌃⌘S)")
                }
            }
            ToolbarItem {
                Button {
                    Task { await model.scan() }
                } label: {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                }
                .help("Scan again (⌘R)")
                .disabled(model.isBusy)
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

    private func row(_ category: JunkCategory) -> some View {
        let size = model.hasScanned ? model.result.size(of: category).bytes : nil
        return HStack(spacing: 10) {
            SymbolTile(symbol: category.symbol, tint: category.tint, size: 22)
            if !compact {
                Text(category.title)
                Spacer()
                if let size {
                    Text(size)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
        .padding(.vertical, 2)
        .help(compact ? [category.title, size].compactMap { $0 }.joined(separator: " · ") : "")
    }

    @ViewBuilder
    private var summary: some View {
        if compact {
            VStack(spacing: 8) {
                if !model.result.unreadable.isEmpty {
                    Button(action: openFullDiskAccess) {
                        Image(systemName: "exclamationmark.lock.fill").foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .help("Some folders need Full Disk Access")
                }
                if model.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Text(model.hasScanned ? model.result.totalSize.bytes : "—")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .help("Found in total")
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        } else {
            fullSummary
        }
    }

    private var fullSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Found").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if model.isBusy { ProgressView().controlSize(.mini) }
            }
            Text(model.hasScanned ? model.result.totalSize.bytes : "—")
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            if !model.result.unreadable.isEmpty {
                Button("Some folders need Full Disk Access") { openFullDiskAccess() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 18)
        .padding(10)
        .animation(.smooth, value: model.result.totalSize)
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
    @Binding var confirming: Bool

    var body: some View {
        let items = model.result.items(in: category)
        ZStack {
            AmbientBackground(tint: category.tint)

            if items.isEmpty {
                VStack {
                    header(items)
                    Spacer()
                    ContentUnavailableView(
                        model.hasScanned ? "Nothing to clean" : "Scanning…",
                        systemImage: model.hasScanned ? "checkmark.circle" : "magnifyingglass"
                    )
                    Spacer()
                }
            } else {
                List {
                    header(items)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    ForEach(items) { item in
                        ItemRow(item: item)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                // Items scroll under the floating bar, which is where glass shows best.
                .safeAreaInset(edge: .bottom) { actionBar(items) }
            }
        }
    }

    private func header(_ items: [CleanupItem]) -> some View {
        HStack(alignment: .center, spacing: 16) {
            SymbolTile(symbol: category.symbol, tint: category.tint, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title).font(.title2.bold())
                Text(category.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.result.size(of: category).bytes)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, tint: category.tint)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func actionBar(_ items: [CleanupItem]) -> some View {
        let allSelected = items.allSatisfy { model.selection.contains($0.url) }
        return GlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    model.selectAll(in: category, !allSelected)
                } label: {
                    Label(allSelected ? "Deselect All" : "Select All",
                          systemImage: allSelected ? "checkmark.circle.fill" : "circle")
                        .padding(.horizontal, 4)
                }
                .glassButton()
                .controlSize(.large)

                Spacer()

                if !model.selection.isEmpty {
                    Text("\(model.selection.count) selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }

                Button {
                    confirming = true
                } label: {
                    Label(model.selection.isEmpty ? "Clean" : "Clean \(model.selectedSize.bytes)",
                          systemImage: "sparkles")
                        .padding(.horizontal, 6)
                        .contentTransition(.numericText())
                }
                .glassButton(prominent: true)
                .tint(category.tint)
                .controlSize(.large)
                .disabled(model.selection.isEmpty || model.isBusy)
                .keyboardShortcut(.delete, modifiers: .command)
            }
            .padding(10)
            .glassCard(cornerRadius: 26)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .animation(.smooth, value: model.selection)
    }
}

struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: CleanupItem

    var body: some View {
        let selected = model.selection.contains(item.url)
        Button {
            model.toggle(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AnyShapeStyle(item.category.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).lineLimit(1)
                    Text(item.url.deletingLastPathComponent().path(percentEncoded: false))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(item.size.bytes)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }
}
