import SwiftUI
import Cocoa

/// A vertical tab sidebar that displays tabs in a vertical list.
/// This provides an alternative to the native horizontal tab bar.
struct VerticalTabSidebar: View {
    /// The window controller that manages the tabs
    weak var windowController: BaseTerminalController?
    
    /// The currently selected tab index
    @State private var selectedIndex: Int = 0
    
    /// All windows in the tab group
    @State private var tabbedWindows: [NSWindow] = []
    
    /// Timer for refreshing the tab list
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(tabbedWindows.enumerated()), id: \.element) { index, window in
                        TabRow(
                            title: window.title,
                            isSelected: index == selectedIndex,
                            keyEquivalent: index < 9 ? "\(index + 1)" : nil,
                            onSelect: {
                                selectTab(at: index)
                            },
                            onClose: {
                                closeTab(window)
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
            tabbedWindows = []
            selectedIndex = 0
            return
        }
        
        // Get all tabbed windows
        if let tabGroup = window.tabGroup {
            tabbedWindows = tabGroup.windows
            
            // Update selected index
            if let selectedWindow = tabGroup.selectedWindow,
               let index = tabbedWindows.firstIndex(of: selectedWindow) {
                selectedIndex = index
            }
        } else {
            tabbedWindows = [window]
            selectedIndex = 0
        }
    }
    
    private func selectTab(at index: Int) {
        guard index >= 0, index < tabbedWindows.count else { return }
        let window = tabbedWindows[index]
        window.makeKeyAndOrderFront(nil)
        selectedIndex = index
    }
    
    private func closeTab(_ window: NSWindow) {
        // If this is the only tab, close the window
        if tabbedWindows.count <= 1 {
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

