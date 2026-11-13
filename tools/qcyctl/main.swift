// Sonda do fone QCY: lê advertising, bateria, versão e estado, e escreve só quando o modo é pedido.
// Roda dentro de um .app assinado por tools/qcyctl/run.sh — sem bundle o TCC aborta o processo por falta de
// NSBluetoothAlwaysUsageDescription. Não loga série.
//
// Uso: tools/qcyctl/run.sh [--seconds 8] [--anc off|anc|outdoor|transparency] [--low-latency on|off] [--ldac on|off]
import CoreBluetooth
import Foundation

final class Tool: @unchecked Sendable {
    private let logURL: URL?
    private let seconds: TimeInterval
    private let packet: QCYPacket?
    private let client = QCYClient()

    init(arguments: [String]) {
        var logPath: String?
        var seconds: TimeInterval = 8
        var packet: QCYPacket?
        var index = 0
        func value(_ flag: String) -> String {
            guard index + 1 < arguments.count else { return "" }
            print("falta valor para \(flag)")
            exit(64)
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
                packet = QCYPacket.noiseCancelMode(mode)
            case "--low-latency":
                index += 1
                guard let enabled = Self.toggle(value(flag)) else { exit(64) }
                packet = QCYPacket.setLowLatency(enabled)
            case "--ldac":
                index += 1
                guard let enabled = Self.toggle(value(flag)) else { exit(64) }
                packet = QCYPacket.setLDAC(enabled)
            default:
                print("argumento desconhecido: \(flag)")
                exit(64)
            }
            index += 1
        }
        self.logURL = logPath.map { URL(fileURLWithPath: $0) }
        self.seconds = seconds
        self.packet = packet
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
        if let noise = state.noiseMode { parts.append("anc \(noise.name) [\(noise.mode)/\(noise.subScene)]") }
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
