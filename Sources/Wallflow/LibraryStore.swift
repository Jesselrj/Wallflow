import Foundation

final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    private struct PersistedLibrary: Codable {
        var wallpapers: [Wallpaper]
        var selectedID: UUID?
        var assignments: [String: UUID]?
    }

    @Published private(set) var wallpapers: [Wallpaper] = []
    @Published private(set) var selectedID: UUID?
    @Published private(set) var assignments: [String: UUID] = [:]

    private let libraryFileURL: URL
    private let samplesDirectory: URL

    var selectedWallpaper: Wallpaper? {
        wallpapers.first { $0.id == selectedID }
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let root = appSupport.appendingPathComponent("Wallflow", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        libraryFileURL = root.appendingPathComponent("library.json")
        samplesDirectory = root.appendingPathComponent("Samples", isDirectory: true)

        load()
        // applyAll 会回调 LibraryStore.shared，init 期间同步调用会重入死锁，故推迟到 runloop
        DispatchQueue.main.async {
            WallpaperManager.shared.applyAll()
        }
    }

    func wallpaper(forScreen screenID: String) -> Wallpaper? {
        let id = assignments[screenID] ?? selectedID
        return wallpapers.first { $0.id == id }
    }

    func select(_ id: UUID?) {
        guard id != selectedID else { return }
        selectedID = id
        assignments.removeAll()
        persist()
        WallpaperManager.shared.applyAll()
    }

    func assign(_ id: UUID, to screenID: String) {
        guard assignments[screenID] != id else { return }
        assignments[screenID] = id
        persist()
        WallpaperManager.shared.applyAll()
    }

    func add(urls: [URL]) {
        var added: [Wallpaper] = []
        for url in urls {
            guard let kind = Wallpaper.kind(forPathExtension: url.pathExtension) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            added.append(Wallpaper(name: name, path: url.path, kind: kind))
        }
        guard !added.isEmpty else { return }
        wallpapers.append(contentsOf: added)
        if selectedID == nil {
            select(added[0].id)
        } else {
            persist()
        }
    }

    func update(_ wallpaper: Wallpaper) {
        guard let index = wallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { return }
        let previous = wallpapers[index]
        wallpapers[index] = wallpaper
        persist()
        WallpaperManager.shared.wallpaperDidChange(wallpaper, previous: previous)
    }

    func remove(ids: Set<UUID>) {
        wallpapers.removeAll { ids.contains($0.id) }
        if let current = selectedID, ids.contains(current) {
            selectedID = wallpapers.first?.id
        }
        for (screenID, wallpaperID) in assignments where ids.contains(wallpaperID) {
            assignments[screenID] = nil
        }
        persist()
        WallpaperManager.shared.applyAll()
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: libraryFileURL),
            let library = try? JSONDecoder().decode(PersistedLibrary.self, from: data)
        else {
            importSamples()
            return
        }
        wallpapers = library.wallpapers
        selectedID = library.selectedID
        assignments = library.assignments ?? [:]
        if wallpapers.isEmpty {
            importSamples()
        }
    }

    private func persist() {
        let library = PersistedLibrary(
            wallpapers: wallpapers,
            selectedID: selectedID,
            assignments: assignments
        )
        if let data = try? JSONEncoder().encode(library) {
            try? data.write(to: libraryFileURL, options: .atomic)
        }
    }

    private func importSamples() {
        let bundled = Bundle.module.urls(forResourcesWithExtension: nil, subdirectory: "Examples") ?? []
        guard !bundled.isEmpty else { return }
        try? FileManager.default.createDirectory(at: samplesDirectory, withIntermediateDirectories: true)

        var samples: [Wallpaper] = []
        for url in bundled.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let destination = samplesDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                continue
            }
            guard let kind = Wallpaper.kind(forPathExtension: destination.pathExtension) else { continue }
            samples.append(Wallpaper(
                name: destination.deletingPathExtension().lastPathComponent,
                path: destination.path,
                kind: kind
            ))
        }

        guard !samples.isEmpty else { return }
        wallpapers.append(contentsOf: samples)
        if selectedID == nil {
            selectedID = samples.first?.id
        }
        persist()
    }
}
