import Foundation

final class LibraryStore: ObservableObject {
    static let shared: LibraryStore = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return LibraryStore(
            directory: appSupport.appendingPathComponent("Wallflow", isDirectory: true),
            applyChanges: { WallpaperManager.shared.applyAll() },
            wallpaperChanged: { WallpaperManager.shared.wallpaperDidChange($0, previous: $1) }
        )
    }()

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
    private let applyChanges: () -> Void
    private let wallpaperChanged: (Wallpaper, Wallpaper) -> Void

    var selectedWallpaper: Wallpaper? {
        wallpapers.first { $0.id == selectedID }
    }

    init(directory: URL, applyChanges: @escaping () -> Void = {},
         wallpaperChanged: @escaping (Wallpaper, Wallpaper) -> Void = { _, _ in }) {
        self.applyChanges = applyChanges
        self.wallpaperChanged = wallpaperChanged
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        libraryFileURL = directory.appendingPathComponent("library.json")
        samplesDirectory = directory.appendingPathComponent("Samples", isDirectory: true)

        load()
        // applyAll 会回调 LibraryStore.shared，init 期间同步调用会重入死锁，故推迟到 runloop
        DispatchQueue.main.async {
            applyChanges()
        }
    }

    func wallpaper(forScreen screenID: String) -> Wallpaper? {
        let id = assignments[screenID] ?? selectedID
        return wallpapers.first { $0.id == id }
    }

    func select(_ id: UUID?) {
        guard id == nil || wallpapers.contains(where: { $0.id == id }) else { return }
        guard id != selectedID || !assignments.isEmpty else { return }
        selectedID = id
        assignments.removeAll()
        persist()
        applyChanges()
    }

    func assign(_ id: UUID, to screenID: String) {
        guard wallpapers.contains(where: { $0.id == id }) else { return }
        guard assignments[screenID] != id else { return }
        assignments[screenID] = id
        persist()
        applyChanges()
    }

    func add(urls: [URL]) {
        var added: [Wallpaper] = []
        var knownPaths = Set(wallpapers.map { $0.url.standardizedFileURL.resolvingSymlinksInPath().path })
        for url in urls {
            guard url.isFileURL else { continue }
            guard let kind = Wallpaper.kind(forPathExtension: url.pathExtension) else { continue }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: url.path)
            else { continue }
            let canonicalPath = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard knownPaths.insert(canonicalPath).inserted else { continue }
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
        wallpaperChanged(wallpaper, previous)
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
        applyChanges()
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
        let validIDs = Set(wallpapers.map(\.id))
        if let id = library.selectedID {
            selectedID = validIDs.contains(id) ? id : wallpapers.first?.id
        } else {
            selectedID = nil
        }
        assignments = (library.assignments ?? [:]).filter { validIDs.contains($0.value) }
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
