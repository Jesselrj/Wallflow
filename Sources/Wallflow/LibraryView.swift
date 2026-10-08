import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var manager = WallpaperManager.shared
    @State private var launchAtLoginError = false
    @State private var screens: [ScreenInfo] = []
    @State private var screenSelection = ScreenInfo.allScreensID

    struct ScreenInfo: Identifiable, Equatable {
        static let allScreensID = "all"
        let id: String
        let name: String
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if screens.count > 1 {
                screenPicker
                Divider()
            }
            if store.wallpapers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.wallpapers) { wallpaper in
                            row(for: wallpaper)
                        }
                    }
                    .padding(.vertical, 6)
                }
                // MenuBarExtra 窗口里 ScrollView 用 maxHeight 会塌陷成 0 高度，必须给固定高度
                .frame(height: min(CGFloat(store.wallpapers.count) * 48 + 16, 340))
            }
            Divider()
            controls
        }
        .frame(width: 320)
        .onAppear(perform: refreshScreens)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshScreens()
        }
    }

    private var header: some View {
        HStack {
            Text("Wallflow").font(.headline)
            Spacer()
            Button {
                showOpenPanel()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("添加壁纸文件")
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 8, trailing: 12))
    }

    private var screenPicker: some View {
        Picker("屏幕", selection: $screenSelection) {
            Text("所有显示器").tag(ScreenInfo.allScreensID)
            ForEach(screens) { screen in
                Text(screen.name).tag(screen.id)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("壁纸库为空").foregroundStyle(.secondary)
            Button("添加壁纸…") {
                showOpenPanel()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var effectiveWallpaperID: UUID? {
        if screenSelection == ScreenInfo.allScreensID {
            return store.selectedID
        }
        return store.assignments[screenSelection] ?? store.selectedID
    }

    private var controlsWallpaper: Wallpaper? {
        if screenSelection == ScreenInfo.allScreensID {
            return store.selectedWallpaper
        }
        return store.wallpaper(forScreen: screenSelection)
    }

    private func row(for wallpaper: Wallpaper) -> some View {
        let isSelected = wallpaper.id == effectiveWallpaperID
        return HStack(spacing: 8) {
            Image(systemName: wallpaper.fileExists ? wallpaper.kind.systemImage : "exclamationmark.triangle.fill")
                .foregroundStyle(wallpaper.fileExists ? Color.secondary : Color.orange)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.name)
                    .lineLimit(1)
                    .foregroundStyle(wallpaper.fileExists ? Color.primary : Color.secondary)
                Text(wallpaper.kind.displayName + (wallpaper.fileExists ? "" : " · 文件缺失"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if screens.count > 1, store.assignments.values.contains(wallpaper.id) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("已单独指定给某块屏幕")
            }
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .onTapGesture {
            if screenSelection == ScreenInfo.allScreensID {
                store.select(wallpaper.id)
            } else {
                store.assign(wallpaper.id, to: screenSelection)
            }
        }
        .contextMenu {
            if screens.count > 1 {
                Menu("指定到屏幕") {
                    ForEach(screens) { screen in
                        Button {
                            store.assign(wallpaper.id, to: screen.id)
                            screenSelection = screen.id
                        } label: {
                            if store.assignments[screen.id] == wallpaper.id {
                                Label(screen.name, systemImage: "checkmark")
                            } else {
                                Text(screen.name)
                            }
                        }
                    }
                }
                Divider()
            }
            Button("移除", role: .destructive) {
                store.remove(ids: [wallpaper.id])
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selected = controlsWallpaper, selected.fileExists {
                HStack(spacing: 12) {
                    Picker("显示", selection: fillModeBinding) {
                        Text("填充").tag(FillMode.fill)
                        Text("适应").tag(FillMode.fit)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                    if selected.kind == .video {
                        Toggle("静音", isOn: mutedBinding)
                            .toggleStyle(.checkbox)
                    }
                }
            }
            HStack {
                Toggle("暂停播放", isOn: $manager.isPaused)
                Spacer()
                Toggle("开机启动", isOn: launchAtLoginBinding)
            }
            HStack {
                if launchAtLoginError {
                    Text("开机启动仅支持 .app 形式运行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("退出 Wallflow") {
                    NSApp.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding(12)
    }

    private var fillModeBinding: Binding<FillMode> {
        Binding(
            get: { controlsWallpaper?.fillMode ?? .fill },
            set: { newValue in
                guard var wallpaper = controlsWallpaper else { return }
                wallpaper.fillMode = newValue
                store.update(wallpaper)
            }
        )
    }

    private var mutedBinding: Binding<Bool> {
        Binding(
            get: { controlsWallpaper?.isMuted ?? true },
            set: { newValue in
                guard var wallpaper = controlsWallpaper else { return }
                wallpaper.isMuted = newValue
                store.update(wallpaper)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { _ in
                do {
                    let enabling = SMAppService.mainApp.status != .enabled
                    if enabling {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    UserDefaults.standard.set(enabling, forKey: "launchAtLogin")
                    launchAtLoginError = false
                } catch {
                    launchAtLoginError = true
                }
            }
        )
    }

    private func refreshScreens() {
        var infos: [ScreenInfo] = []
        for (index, screen) in NSScreen.screens.enumerated() {
            infos.append(ScreenInfo(
                id: ScreenIdentity.identifier(for: screen),
                name: ScreenIdentity.name(for: screen, index: index)
            ))
        }
        screens = infos
        if screenSelection != ScreenInfo.allScreensID,
           !infos.contains(where: { $0.id == screenSelection }) {
            screenSelection = ScreenInfo.allScreensID
        }
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "选择视频、GIF、图片或 HTML 文件"
        var contentTypes: [UTType] = []
        for fileExtension in Wallpaper.supportedExtensions {
            if let type = UTType(filenameExtension: fileExtension) {
                contentTypes.append(type)
            }
        }
        panel.allowedContentTypes = contentTypes
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            store.add(urls: panel.urls)
        }
    }
}
