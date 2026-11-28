import Foundation
import Security

/// Daemon privilegiado mínimo (`SMAppService.daemon`, ADR 0009): aceita apenas troca de `pmset powermode`
/// vinda do app `com.lucasstop.LogiBattery`.
final class PowerHelperService: NSObject, NSXPCListenerDelegate, PowerHelperProtocol {
    private let allowedScopes: Set<String> = ["-c", "-b"]
    private let ownTeamIdentifier: String?

    override init() {
        self.ownTeamIdentifier = Self.teamIdentifier(forSelf: true)
        super.init()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard isAuthorizedClient(pid: newConnection.processIdentifier) else { return false }
        newConnection.exportedInterface = NSXPCInterface(with: PowerHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func ping(withReply reply: @escaping (String) -> Void) {
        reply("ok")
    }

    func setPowerMode(_ mode: Int, scope: String, withReply reply: @escaping (Bool, String?) -> Void) {
        guard (0...2).contains(mode), allowedScopes.contains(scope) else {
            reply(false, "Invalid powermode arguments")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = [scope, "powermode", "\(mode)"]
        let stderr = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                reply(true, nil)
            } else {
                let data = stderr.fileHandleForReading.readDataToEndOfFile()
                let message = String(bytes: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "pmset failed"
                reply(false, message.isEmpty ? "pmset exited with status \(process.terminationStatus)" : message)
            }
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    private func isAuthorizedClient(pid: pid_t) -> Bool {
        var code: SecCode?
        let attributes = [kSecGuestAttributePid: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let guest = code else { return false }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(guest, [], &staticCode) == errSecSuccess,
              let staticRef = staticCode else { return false }

        var infoCF: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticRef, flags, &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any],
              let identifier = info[kSecCodeInfoIdentifier as String] as? String,
              identifier == PowerHelperConstants.hostBundleIdentifier else { return false }

        if let ownTeam = ownTeamIdentifier, !ownTeam.isEmpty {
            let clientTeam = info[kSecCodeInfoTeamIdentifier as String] as? String
            return clientTeam == ownTeam
        }
        return true
    }

    private static func teamIdentifier(forSelf: Bool) -> String? {
        guard forSelf else { return nil }
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let selfCode = code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &staticCode) == errSecSuccess,
              let staticRef = staticCode else { return nil }
        var infoCF: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticRef, flags, &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any] else { return nil }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }
}

let delegate = PowerHelperService()
let listener = NSXPCListener(machServiceName: PowerHelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
