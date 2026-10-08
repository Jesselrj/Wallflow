import AppKit

protocol WallpaperRenderer: AnyObject {
    var view: NSView { get }
    func setPaused(_ paused: Bool)
    func setMuted(_ muted: Bool)
    func stop()
}

extension WallpaperRenderer {
    func setMuted(_ muted: Bool) {}
}

enum WallpaperRendererFactory {
    static func makeRenderer(for wallpaper: Wallpaper) -> WallpaperRenderer? {
        switch wallpaper.kind {
        case .video:
            return VideoWallpaperRenderer(wallpaper: wallpaper)
        case .gif, .image:
            return FrameSequenceWallpaperRenderer(wallpaper: wallpaper)
        case .web:
            return WebWallpaperRenderer(wallpaper: wallpaper)
        }
    }
}
