import SwiftUI

/// Cor por nível (DESIGN.md §3.1); cor nunca é o único sinal, o texto do nível acompanha.
extension BatteryLevel {
    var color: Color {
        switch self {
        case .normal: Color(light: 0x1F9D55, dark: 0x34C77B)
        case .low: Color(light: 0xB7791F, dark: 0xF2B13C)
        case .critical: Color(light: 0xC53030, dark: 0xFF6B6B)
        case .unknown: .secondary
        }
    }

    var labelKey: LocalizedStringKey? {
        switch self {
        case .low: "level.low"
        case .critical: "level.critical"
        case .normal, .unknown: nil
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

/// Célula de bateria: barra preenchida até o percentual.
struct BatteryCell: View {
    let percent: Int?
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(tint).frame(width: proxy.size.width * CGFloat(min(max(percent ?? 0, 0), 100)) / 100)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

extension Device {
    /// Cor do nível; carregando usa `info` (DESIGN.md), igual ao protótipo.
    func tint(_ thresholds: BatteryThresholds) -> Color {
        chargeState == .charging ? Color(light: 0x2B6CB0, dark: 0x63B3ED)
            : BatteryLevel(percent: percent, thresholds: thresholds).color
    }

    /// Mouse, teclado e fone usam o símbolo próprio com o selo de conexão dentro (Symbols.xcassets, gerado por
    /// design/symbols/make.py); o resto, o SF Symbol do sistema com o `TransportBadge` ao lado.
    var symbolName: String {
        switch (kind, path) {
        case (.mouse, .bluetooth), (.mouse, .receiver), (.keyboard, .bluetooth), (.keyboard, .receiver),
             (.headphones, .bluetooth):
            "lb.\(kind.rawValue).\(path.rawValue)"
        case (.mouse, _): "computermouse"
        case (.keyboard, _): "keyboard"
        case (.laptop, _): "laptopcomputer"
        case (.headphones, _): "headphones"
        case (.other, _): "dot.radiowaves.left.and.right"
        }
    }

    var symbolHasBadge: Bool { symbolName.hasPrefix("lb.") }

    /// O selo vira parte do desenho, então a conexão vai no rótulo do VoiceOver.
    var symbol: Image {
        symbolHasBadge ? Image(symbolName, label: Text(path.labelKey)) : Image(systemName: symbolName)
    }
}

/// Runa do Bluetooth; o SF Symbols não traz o logotipo.
private struct BluetoothRune: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [(0.2, 0.7), (0.8, 0.3), (0.5, 0.05), (0.5, 0.95), (0.8, 0.7), (0.2, 0.3)]
            .map { CGPoint(x: rect.minX + $0.0 * rect.width, y: rect.minY + $0.1 * rect.height) }
        var path = Path()
        path.addLines(points)
        return path
    }
}

/// Como o aparelho está conectado agora: Bluetooth ou receptor USB. A bateria do próprio Mac não leva selo, nem o
/// aparelho cujo símbolo já traz o selo (`symbolHasBadge`).
struct TransportBadge: View {
    let device: Device
    private var path: DevicePath { device.path }

    var body: some View {
        if path != .internal, !device.symbolHasBadge {
            Group {
                if path == .bluetooth {
                    BluetoothRune().stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                        .frame(width: 8, height: 11)
                } else {
                    Image(systemName: "cable.connector").font(.system(size: 10))
                }
            }
            .foregroundStyle(.secondary)
            .frame(width: 12, height: 12)
            .accessibilityLabel(Text(path.labelKey))
        }
    }
}
