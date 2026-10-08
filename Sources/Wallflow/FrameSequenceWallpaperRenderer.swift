import AppKit
import ImageIO

final class FrameSequenceWallpaperRenderer: WallpaperRenderer {
    final class ContentView: NSView {
        let contentLayer = CALayer()

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            contentLayer.backgroundColor = NSColor.black.cgColor
            layer?.addSublayer(contentLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            contentLayer.frame = bounds
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let scale = window?.backingScaleFactor {
                contentLayer.contentsScale = scale
            }
        }

        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            if let scale = window?.backingScaleFactor {
                contentLayer.contentsScale = scale
            }
        }
    }

    let view: NSView
    private let contentView: ContentView
    private var frames: [CGImage] = []
    private var frameDurations: [Double] = []
    private var frameIndex = 0
    private var timer: Timer?
    private var paused = false

    init?(wallpaper: Wallpaper) {
        contentView = ContentView()
        view = contentView
        contentView.contentLayer.contentsGravity = wallpaper.fillMode == .fill ? .resizeAspectFill : .resizeAspect

        var loadedFrames: [CGImage] = []
        var loadedDurations: [Double] = []
        guard Self.loadFrames(from: wallpaper.url, into: &loadedFrames, durations: &loadedDurations), !loadedFrames.isEmpty else {
            return nil
        }
        frames = loadedFrames
        frameDurations = loadedDurations
        contentView.contentLayer.contents = frames[0]
    }

    private static func loadFrames(from url: URL, into frames: inout [CGImage], durations: inout [Double]) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        let count = CGImageSourceGetCount(source)
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(image)
            durations.append(frameDuration(at: index, in: source))
        }
        return !frames.isEmpty
    }

    private static func frameDuration(at index: Int, in source: CGImageSource) -> Double {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }
        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped ?? 0.1
        return duration > 0.01 ? duration : 0.1
    }

    func setPaused(_ newPaused: Bool) {
        guard newPaused != paused else { return }
        paused = newPaused
        if paused {
            timer?.invalidate()
            timer = nil
        } else {
            scheduleNextFrame()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextFrame() {
        guard frames.count > 1 else { return }
        let interval = max(frameDurations[frameIndex], 0.02)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        frameIndex = (frameIndex + 1) % frames.count
        contentView.contentLayer.contents = frames[frameIndex]
        scheduleNextFrame()
    }
}
