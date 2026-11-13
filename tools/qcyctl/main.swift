// Sonda do fone QCY: lê advertising, bateria, versão e estado, e escreve só quando o modo é pedido.
// Roda dentro de um .app assinado por tools/qcyctl/run.sh — sem bundle o TCC aborta o processo por falta de
// NSBluetoothAlwaysUsageDescription. Não loga série.
//
// Uso: tools/qcyctl/run.sh [--seconds 8] [--anc off|anc|outdoor|transparency] [--scene MM/SS/NV em hex]
//                              [--low-latency on|off] [--ldac on|off] [--verbose]
import CoreBluetooth
import Foundation

final class Tool: @unchecked Sendable {
    private let logURL: URL?
    private let seconds: TimeInterval
    private let packet: QCYPacket?
    private let verbose: Bool
    private let client = QCYClient()

    init(arguments: [String]) {
        var logPath: String?
        var seconds: TimeInterval = 8
        var blocks: [QCYPacket.Block] = []
        var verbose = false
        var index = 0
        func value(_ flag: String) -> String {
            guard index < arguments.count else {
                print("falta valor para \(flag)")
                exit(64)
            }
            return arguments[index]
        }
        while index < arguments.count {
            let flag = arguments[index]
            switch flag {
            case "--log":
                index += 1
                logPath = index < arguments.count ? arguments[index] : nil
            case "--seconds":
                index += 1
                seconds = TimeInterval(index < arguments.count ? arguments[index] : "") ?? seconds
            case "--anc":
                index += 1
                let modes: [String: UInt8] = ["off": 0x00, "anc": 0x01, "outdoor": 0x02, "transparency": 0x03]
                guard let mode = modes[value(flag)] else { exit(64) }
                blocks += QCYPacket.noiseCancelMode(mode).blocks
            case "--scene":
                index += 1
                guard let scene = Self.scene(value(flag)) else { exit(64) }
                blocks += QCYPacket.ancSetting(mode: scene.mode,
                                               subScene: scene.subScene,
                                               noiseValue: scene.noiseValue).blocks
            case "--low-latency":
                index += 1
                guard let enabled = Self.toggle(value(flag)) else { exit(64) }
                blocks += QCYPacket.setLowLatency(enabled).blocks
            case "--ldac":
                index += 1
                guard let enabled = Self.toggle(value(flag)) else { exit(64) }
                blocks += QCYPacket.setLDAC(enabled).blocks
            case "--verbose":
                verbose = true
            default:
                print("argumento desconhecido: \(flag)")
                exit(64)
            }
            index += 1
        }
        self.logURL = logPath.map { URL(fileURLWithPath: $0) }
        self.seconds = seconds
        self.packet = blocks.isEmpty ? nil : QCYPacket(blocks)
        self.verbose = verbose
    }

    /// `MM/SS/NV` em hexadecimal, como o fone devolve em `0x17`.
    private static func scene(_ text: String) -> (mode: UInt8, subScene: UInt8, noiseValue: UInt8)? {
        let parts = text.split(separator: "/")
        guard parts.count == 3,
              let mode = UInt8(parts[0], radix: 16),
              let subScene = UInt8(parts[1], radix: 16),
              let noiseValue = UInt8(parts[2], radix: 16) else { return nil }
        return (mode, subScene, noiseValue)
    }

    private static func toggle(_ text: String) -> Bool? {
        switch text {
        case "on", "1", "true": return true
        case "off", "0", "false": return false
        default: return nil
        }
    }

    func run() {
        log("procurando QCY por manufacturer data 0x521C…")
        client.onAdvertisement = { [weak self] advertisement in
            self?.log("advertising: vendor=\(String(format: "0x%04X", advertisement.vendorID)) "
                      + "L=\(advertisement.left.percent)%\(advertisement.left.isCharging ? " (carregando)" : "") "
                      + "R=\(advertisement.right.percent)%\(advertisement.right.isCharging ? " (carregando)" : "") "
                      + "estojo=\(advertisement.caseBattery.map { "\($0.percent)%" } ?? "-") "
                      + "control=\(advertisement.controlMAC ?? "-") outr=\(advertisement.otherMAC ?? "-")")
        }
        client.onPacket = { [weak self] data in
            guard let self, self.verbose else { return }
            self.log("rx " + data.map { String(format: "%02x", $0) }.joined(separator: " "))
        }
        client.onState = { [weak self] state in
            self?.log(Self.describe(state))
        }
        client.onReady = { [weak self] in
            guard let self, let packet else { return }
            self.log("escrevendo \(packet.encoded().map { String(format: "%02x", $0) }.joined(separator: " "))")
            self.client.send(packet)
        }
        client.onFailure = { [weak self] message in
            self?.log("falha: \(message)")
        }
        client.start()
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        client.stop()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        log("fim")
    }

    private static func describe(_ state: QCYState) -> String {
        var parts: [String] = []
        if let left = state.left, let right = state.right {
            parts.append("bateria L=\(left.percent)%\(left.isCharging ? "+" : "") "
                         + "R=\(right.percent)%\(right.isCharging ? "+" : "") "
                         + "estojo=\(state.caseBattery.map { "\($0.percent)%\($0.isCharging ? "+" : "")" } ?? "-")")
        }
        if let firmware = state.firmware {
            parts.append("firmware \(firmware.left)\(firmware.right.map { " / \($0)" } ?? "")")
        }
        if let mode = state.noiseCancelMode { parts.append("anc \(mode.name)") }
        if let scene = state.ancScene { parts.append("cena \(scene.name)") }
        if let lowLatency = state.isLowLatencyEnabled { parts.append("jogo \(lowLatency ? "on" : "off")") }
        if let ldac = state.isLDACEnabled { parts.append("ldac \(ldac ? "on" : "off")") }
        if let inEar = state.isInEarDetectionEnabled { parts.append("deteccao de ouvido \(inEar ? "on" : "off")") }
        return parts.isEmpty ? "estado sem blocos conhecidos" : parts.joined(separator: " · ")
    }

    private func log(_ text: String) {
        print(text)
        guard let logURL, let data = (text + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    }
}

Tool(arguments: Array(CommandLine.arguments.dropFirst())).run()
