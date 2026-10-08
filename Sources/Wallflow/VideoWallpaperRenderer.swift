import AppKit
import AVFoundation

final class VideoWallpaperRenderer: WallpaperRenderer {
    let view: NSView
    private let playerView: PlayerView
    private let player: AVQueuePlayer
    private let looper: AVPlayerLooper

    init?(wallpaper: Wallpaper) {
        let item = AVPlayerItem(url: wallpaper.url)
        player = AVQueuePlayer()
        looper = AVPlayerLooper(player: player, templateItem: item)
        playerView = PlayerView()
        view = playerView
        playerView.player = player
        playerView.videoGravity = wallpaper.fillMode == .fill ? .resizeAspectFill : .resizeAspect
        player.isMuted = wallpaper.isMuted
    }

    func setPaused(_ paused: Bool) {
        if paused {
            player.pause()
        } else {
            player.play()
        }
    }

    func setMuted(_ muted: Bool) {
        player.isMuted = muted
    }

    func stop() {
        player.pause()
    }
}

final class PlayerView: NSView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    init() {
        super.init(frame: .zero)
        layer = playerLayer
        wantsLayer = true
        playerLayer.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
