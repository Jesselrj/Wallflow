import AppKit
import ObjectiveC
import WebKit

// 通过 IMP 类型转换调用私有 API，避免 perform(_:with:) 传 BOOL 的指针歧义。
// 方法不存在时静默跳过，兼容未来系统移除。
private func callBoolSetter(on object: AnyObject, selector: Selector, _ value: Bool) {
    guard let cls = object_getClass(object),
          let method = class_getInstanceMethod(cls, selector) else { return }
    let imp = method_getImplementation(method)
    typealias BoolSetter = @convention(c) (AnyObject, Selector, Bool) -> Void
    unsafeBitCast(imp, to: BoolSetter.self)(object, selector, value)
}

// 壁纸窗口必然被 Finder 图标层窗口遮挡，WebKit 会据此把页面标记为 hidden，
// 挂起 requestAnimationFrame 和 DOM 定时器。这里关闭该检测让网页动画常驻。
private func applyOcclusionBypass(to webView: WKWebView) {
    callBoolSetter(on: webView, selector: NSSelectorFromString("_setWindowOcclusionDetectionEnabled:"), false)
    let preferences = webView.configuration.preferences
    callBoolSetter(on: preferences, selector: NSSelectorFromString("_setHiddenPageDOMTimerThrottlingEnabled:"), false)
    callBoolSetter(on: preferences, selector: NSSelectorFromString("_setDOMTimersThrottlingEnabled:"), false)
    callBoolSetter(on: preferences, selector: NSSelectorFromString("_setPageVisibilityBasedProcessSuppressionEnabled:"), false)
}

final class WebWallpaperRenderer: WallpaperRenderer {
    let view: NSView
    private let webView: WKWebView

    init?(wallpaper: Wallpaper) {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        view = webView
        webView.autoresizingMask = [.width, .height]
        webView.underPageBackgroundColor = .black
        applyOcclusionBypass(to: webView)
        webView.loadFileURL(wallpaper.url, allowingReadAccessTo: wallpaper.url.deletingLastPathComponent())
    }

    func setPaused(_ paused: Bool) {
        webView.setAllMediaPlaybackSuspended(paused, completionHandler: nil)
    }

    func stop() {
        webView.stopLoading()
        webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
    }
}
