import SwiftUI
import Cocoa

/// A vertical tab sidebar that displays tabs in a vertical list.
/// This provides an alternative to the native horizontal tab bar.
struct VerticalTabSidebar: View {
    /// The window controller that manages the tabs
    weak var windowController: BaseTerminalController?
    
    /// The tab data model that tracks all tabs
    @StateObject private var tabModel = TabModel()
    
    /// Timer for refreshing the tab list
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(tabModel.tabs) { tab in
                        TabRow(
                            title: tab.title,
                            isSelected: tab.isSelected,
                            keyEquivalent: tab.index < 9 ? "\(tab.index + 1)" : nil,
                            onSelect: {
                                selectTab(tab.window)
                            },
                            onClose: {
                                closeTab(tab.window)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // Footer with new tab button
            HStack(spacing: 8) {
                Button(action: createNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("New Tab")
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 200)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onAppear {
            refreshTabs()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    // MARK: - Tab Data Model
    
    /// Represents a single tab's data
    struct TabData: Identifiable {
        let id: String  // Unique ID combining window hash and title for proper updates
        let window: NSWindow
        let title: String
        let index: Int
        let isSelected: Bool
        
        init(window: NSWindow, index: Int, isSelected: Bool) {
            self.window = window
            self.title = window.title
            self.index = index
            self.isSelected = isSelected
            // Use a combination of window hash and title to force updates when title changes
            self.id = "\(ObjectIdentifier(window).hashValue)-\(window.title)"
        }
    }
    
    /// Observable model that holds the tab list
    class TabModel: ObservableObject {
        @Published var tabs: [TabData] = []
    }
    
    // MARK: - Tab Row
    
    struct TabRow: View {
        let title: String
        let isSelected: Bool
        let keyEquivalent: String?
        let onSelect: () -> Void
        let onClose: () -> Void
        
        @State private var isHovering: Bool = false
        
        var body: some View {
            HStack(spacing: 6) {
                // Key equivalent badge
                if let keyEquiv = keyEquivalent {
                    Text("⌘\(keyEquiv)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 28)
                }
                
                // Tab title
                Text(title.isEmpty ? "Ghostty" : title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                // Close button (shown on hover)
                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close Tab")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Actions
    
    private func refreshTabs() {
        guard let window = windowController?.window else {
            tabModel.tabs = []
            return
        }
        
        // Get all tabbed windows and the selected one
        let windows: [NSWindow]
        let selectedWindow: NSWindow?
        
        if let tabGroup = window.tabGroup {
            windows = tabGroup.windows
            selectedWindow = tabGroup.selectedWindow
        } else {
            windows = [window]
            selectedWindow = window
        }
        
        // Build the tab data with current titles
        let newTabs = windows.enumerated().map { index, win in
            TabData(
                window: win,
                index: index,
                isSelected: win == selectedWindow
            )
        }
        
        // Only update if something changed (to avoid unnecessary re-renders)
        let newIds = newTabs.map { $0.id }
        let oldIds = tabModel.tabs.map { $0.id }
        
        if newIds != oldIds {
            tabModel.tabs = newTabs
        }
    }
    
    private func selectTab(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        refreshTabs()
    }
    
    private func closeTab(_ window: NSWindow) {
        // If this is the only tab, close the window
        if tabModel.tabs.count <= 1 {
            window.close()
            return
        }
        
        // Otherwise just close this tab
        window.close()
        
        // Refresh after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            refreshTabs()
        }
    }
    
    private func createNewTab() {
        guard let surface = windowController?.focusedSurface?.surface else { return }
        windowController?.ghostty.newTab(surface: surface)
        
        // Refresh after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            refreshTabs()
        }
    }
    
    // MARK: - Timer
    
    private func startRefreshTimer() {
        // Refresh tabs periodically to catch changes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            refreshTabs()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Preview

#if DEBUG
struct VerticalTabSidebar_Previews: PreviewProvider {
    static var previews: some View {
        VerticalTabSidebar(windowController: nil)
            .frame(height: 400)
    }
}
#endif

