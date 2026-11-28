import AppKit
import Foundation

enum PowerHelperError: LocalizedError {
    case invalidArguments
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments: "Invalid powermode arguments"
        case .scriptFailed(let message): message
        }
    }
}

/// Troca o Modo de Energia com `pmset` elevado. Com a regra de `sudoers` instalada (uma senha, `register()`),
/// roda `sudo -n` sem pedir senha; sem ela, cai em `do shell script ... with administrator privileges` (senha a cada
/// troca). Sem Developer ID o `SMAppService.daemon` não registra (ADR 0009, revisado).
struct PowerHelperClient: PowerModeControlling {
    private static let rulePath = "/etc/sudoers.d/logibattery"
    private static let scopes = ["-c", "-b"]

    func status() -> PowerHelperStatus {
        // /etc/sudoers.d não é legível pelo usuário: lê a lista do sudo e procura a nossa regra NOPASSWD.
        // (`sudo -l <comando>` não serve: dá certo também para quem tem `ALL` com senha.)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "-l"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return .notRegistered }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let listing = String(bytes: data, encoding: .utf8) ?? ""
        let rule = listing.contains("NOPASSWD") && listing.contains("/usr/bin/pmset -c powermode 0")
        return rule ? .enabled : .notRegistered
    }

    /// Instala a regra `NOPASSWD` só para `pmset -c|-b powermode 0|1|2`, validada com `visudo -cf`.
    func register() throws -> PowerHelperStatus {
        let user = NSUserName()
        guard user.range(of: "^[a-z_][a-z0-9_.-]*$", options: [.regularExpression, .caseInsensitive]) != nil else {
            throw PowerHelperError.invalidArguments
        }
        let commands = Self.scopes.flatMap { scope in
            (0...2).map { "/usr/bin/pmset \(scope) powermode \($0)" }
        }.joined(separator: ", ")
        let rule = "\(user) ALL=(root) NOPASSWD: \(commands)"
        let shell = "f=$(/usr/bin/mktemp) && /usr/bin/printf '%s\\n' '\(rule)' > \"$f\" && "
            + "/usr/sbin/visudo -cf \"$f\" && /usr/bin/install -m 0440 -o root -g wheel \"$f\" \(Self.rulePath); "
            + "rc=$?; /bin/rm -f \"$f\"; exit $rc"
        try Self.runAdminOrThrow(shell)
        return status()
    }

    /// Volta a exigir senha: apaga a regra.
    func revoke() throws {
        let command = "/bin/rm -f \(Self.rulePath)"
        try Self.runAdminOrThrow(command)
    }

    func setPowerMode(_ mode: EnergyMode, scope: String) async throws {
        // Só valores conhecidos entram no comando: nada vindo de fora é concatenado.
        guard Self.scopes.contains(scope) else { throw PowerHelperError.invalidArguments }
        let arguments = ["/usr/bin/pmset", scope, "powermode", "\(mode.rawValue)"]
        if status() == .enabled, Self.runSudo(arguments) { return }
        let command = arguments.joined(separator: " ")
        if let failure = await MainActor.run(body: { Self.runAsAdmin(command) }) {
            throw PowerHelperError.scriptFailed(failure)
        }
    }

    private static func runAdminOrThrow(_ shell: String) throws {
        if let failure = MainActor.assumeIsolated({ runAsAdmin(shell) }) {
            throw PowerHelperError.scriptFailed(failure)
        }
    }

    /// `true` se o `sudo -n` (sem senha) terminou com sucesso.
    private static func runSudo(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n"] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Roda `shell` como administrador (pede a senha). `nil` em sucesso ou cancelamento (-128); senão a mensagem.
    @MainActor
    private static func runAsAdmin(_ shell: String) -> String? {
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var info: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&info)
        guard let info else { return nil }
        if info[NSAppleScript.errorNumber] as? Int == -128 { return nil }
        return info[NSAppleScript.errorMessage] as? String ?? "pmset failed"
    }
}

/// Ações nativas do sistema relacionadas à bateria do Mac.
enum MacPowerActions {
    private static let batterySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Battery-Settings.extension"
    )!

    @MainActor
    static func openBatterySettings() {
        NSWorkspace.shared.open(batterySettingsURL)
    }
}
