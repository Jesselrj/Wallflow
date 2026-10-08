import AppKit

final class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    @Published var isPaused = false {
        didSet { syncPlaybackState() }
    }

    private struct ScreenEntry {
        let panel: WallpaperPanel
        let renderer: WallpaperRenderer
        let wallpaperID: UUID
        let fillMode: FillMode
    }

    private var entries: [String: ScreenEntry] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAll()
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncPlaybackState()
        }
        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pauseRenderers()
        }
        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncPlaybackState()
        }
    }

    func applyAll() {
        var seen = Set<String>()

        for screen in NSScreen.screens {
            let screenID = ScreenIdentity.identifier(for: screen)
            seen.insert(screenID)
            let wallpaper = LibraryStore.shared.wallpaper(forScreen: screenID)

            if let entry = entries[screenID],
               entry.wallpaperID == wallpaper?.id,
               entry.fillMode == wallpaper?.fillMode {
                entry.panel.setFrame(screen.frame, display: false)
                continue
            }

            removeEntry(for: screenID)
            guard let wallpaper, wallpaper.fileExists,
                  let renderer = WallpaperRendererFactory.makeRenderer(for: wallpaper)
            else { continue }

            let panel = WallpaperPanel(frame: screen.frame)
            renderer.view.frame = NSRect(origin: .zero, size: screen.frame.size)
            renderer.view.autoresizingMask = [.width, .height]
            panel.contentView = renderer.view
            panel.show()
            entries[screenID] = ScreenEntry(
                panel: panel,
                renderer: renderer,
                wallpaperID: wallpaper.id,
                fillMode: wallpaper.fillMode
            )
        }

        for screenID in entries.keys where !seen.contains(screenID) {
            removeEntry(for: screenID)
        }

        syncPlaybackState()
    }

    func wallpaperDidChange(_ wallpaper: Wallpaper, previous: Wallpaper) {
        if previous.fillMode != wallpaper.fillMode {
            for (screenID, entry) in entries where entry.wallpaperID == wallpaper.id {
                removeEntry(for: screenID)
            }
            applyAll()
        } else if previous.isMuted != wallpaper.isMuted {
            for entry in entries.values where entry.wallpaperID == wallpaper.id {
                entry.renderer.setMuted(wallpaper.isMuted)
            }
        }
    }

    private func removeEntry(for screenID: String) {
        guard let entry = entries.removeValue(forKey: screenID) else { return }
        entry.panel.orderOut(nil)
        entry.renderer.stop()
    }

    private func syncPlaybackState() {
        for entry in entries.values {
            entry.renderer.setPaused(isPaused)
        }
    }

    private func pauseRenderers() {
        for entry in entries.values {
            entry.renderer.setPaused(true)
        }
    }
}
