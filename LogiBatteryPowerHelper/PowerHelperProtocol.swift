import Foundation

public enum PowerHelperConstants {
    public static let machServiceName = "com.lucasstop.LogiBattery.power-helper"
    public static let plistName = "com.lucasstop.LogiBattery.power-helper.plist"
    public static let hostBundleIdentifier = "com.lucasstop.LogiBattery"
}

/// Contrato XPC mínimo entre o app host e o daemon privilegiado (ADR 0009).
@objc public protocol PowerHelperProtocol {
    func setPowerMode(_ mode: Int, scope: String, withReply reply: @escaping (Bool, String?) -> Void)
    func ping(withReply reply: @escaping (String) -> Void)
}
