import AppKit
import CoreGraphics

enum ScreenIdentity {
    private static let uuidFromDisplayID: (CGDirectDisplayID) -> CFUUID? = {
        typealias Fn = @convention(c) (UInt32) -> UnsafeMutableRawPointer?
        guard let handle = dlopen(nil, RTLD_LAZY),
              let symbol = dlsym(handle, "CGDisplayCreateUUIDFromDisplayID")
        else { return { _ in nil } }
        let fn = unsafeBitCast(symbol, to: Fn.self)
        return { displayID in
            guard let raw = fn(displayID) else { return nil }
            return unsafeBitCast(raw, to: CFUUID.self)
        }
    }()

    static func identifier(for screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return screen.localizedName
        }
        let displayID = number.uint32Value
        if let uuid = uuidFromDisplayID(displayID),
           let string = CFUUIDCreateString(nil, uuid) as String? {
            return string
        }
        return "v\(CGDisplayVendorNumber(displayID))-m\(CGDisplayModelNumber(displayID))-s\(CGDisplaySerialNumber(displayID))"
    }

    static func name(for screen: NSScreen, index: Int) -> String {
        let name = screen.localizedName
        if !name.isEmpty { return name }
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        if let number, CGDisplayIsBuiltin(number.uint32Value) == 1 {
            return "内建显示器"
        }
        return "显示器 \(index + 1)"
    }
}
