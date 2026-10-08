import ServiceManagement
import SwiftUI

@main
struct WallflowApp: App {
    private let store = LibraryStore.shared

    init() {
        if UserDefaults.standard.object(forKey: "launchAtLogin") == nil {
            UserDefaults.standard.set(SMAppService.mainApp.status == .enabled, forKey: "launchAtLogin")
        }
        if UserDefaults.standard.bool(forKey: "launchAtLogin") {
            // app 被移动过位置后重新注册，登录项才会指向新路径
            try? SMAppService.mainApp.register()
        }
    }

    var body: some Scene {
        MenuBarExtra("Wallflow", systemImage: "photo.artframe") {
            LibraryView()
        }
        .menuBarExtraStyle(.window)
    }
}
