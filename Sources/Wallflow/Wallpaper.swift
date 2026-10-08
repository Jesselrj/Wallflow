import Foundation

enum WallpaperKind: String, Codable, CaseIterable {
    case video
    case gif
    case image
    case web

    var displayName: String {
        switch self {
        case .video: return "视频"
        case .gif: return "GIF"
        case .image: return "图片"
        case .web: return "网页"
        }
    }

    var systemImage: String {
        switch self {
        case .video: return "film"
        case .gif: return "photo.on.rectangle.angled"
        case .image: return "photo"
        case .web: return "globe"
        }
    }
}

enum FillMode: String, Codable, CaseIterable {
    case fill
    case fit

    var displayName: String {
        switch self {
        case .fill: return "填充"
        case .fit: return "适应"
        }
    }
}

struct Wallpaper: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var path: String
    var kind: WallpaperKind
    var fillMode: FillMode = .fill
    var isMuted = true

    var url: URL { URL(fileURLWithPath: path) }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func kind(forPathExtension pathExtension: String) -> WallpaperKind? {
        switch pathExtension.lowercased() {
        case "mp4", "mov", "m4v":
            return .video
        case "gif":
            return .gif
        case "png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp":
            return .image
        case "html", "htm":
            return .web
        default:
            return nil
        }
    }

    static let supportedExtensions = [
        "mp4", "mov", "m4v",
        "gif",
        "png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp",
        "html", "htm",
    ]
}
