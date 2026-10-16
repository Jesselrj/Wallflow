import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Wallflow

final class PlaybackTests: XCTestCase {
    func testSleepAndUserPauseRemainIndependent() {
        var state = PlaybackState()
        XCTAssertFalse(state.isPaused)
        state.screensSleeping = true
        XCTAssertTrue(state.isPaused)
        state.userPaused = true
        state.screensSleeping = false
        XCTAssertTrue(state.isPaused)
        state.systemSleeping = true
        state.userPaused = false
        XCTAssertTrue(state.isPaused)
        state.systemSleeping = false
        XCTAssertFalse(state.isPaused)
    }

    func testSystemWakeDoesNotOverrideSleepingDisplays() {
        var state = PlaybackState(systemSleeping: true, screensSleeping: true)
        state.systemSleeping = false
        XCTAssertTrue(state.isPaused)
        state.screensSleeping = false
        XCTAssertFalse(state.isPaused)
    }

    func testGIFStartsOnFirstResumePausesAndCanRestartAfterStop() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).gif")
        defer { try? FileManager.default.removeItem(at: url) }
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 2, nil))
        for component in [0.0, 1.0] {
            let context = try XCTUnwrap(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
                                                bytesPerRow: 8, space: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(red: component, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()),
                                      [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.05]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let renderer = try XCTUnwrap(FrameSequenceWallpaperRenderer(
            wallpaper: Wallpaper(name: "test", path: url.path, kind: .gif)))
        defer { renderer.stop() }
        let content = try XCTUnwrap(renderer.view as? FrameSequenceWallpaperRenderer.ContentView)
        func currentFrame() throws -> CGImage { try XCTUnwrap(content.contentLayer.contents as! CGImage?) }
        func waitForChange(from frame: CGImage) {
            let changed = expectation(description: "GIF advances to another frame")
            let observer = Timer(timeInterval: 0.005, repeats: true) { timer in
                if let current = content.contentLayer.contents as! CGImage?, !(frame === current) {
                    // 首次切帧后冻结，避免等待器回到测试代码前 GIF 又循环到原帧。
                    renderer.setPaused(true)
                    timer.invalidate()
                    changed.fulfill()
                }
            }
            RunLoop.main.add(observer, forMode: .common)
            defer { observer.invalidate() }
            wait(for: [changed], timeout: 1)
        }
        let first = try currentFrame()
        renderer.setPaused(false)
        waitForChange(from: first)
        let second = try currentFrame()
        XCTAssertFalse(first === second, "首次播放状态同步必须启动 GIF")
        renderer.setPaused(true)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.075))
        XCTAssertTrue(second === (try currentFrame()))
        renderer.setPaused(false)
        waitForChange(from: second)
        renderer.setPaused(false)
        renderer.stop()
        let stopped = try currentFrame()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.075))
        XCTAssertTrue(stopped === (try currentFrame()))
        renderer.setPaused(false)
        waitForChange(from: stopped)
    }
}
