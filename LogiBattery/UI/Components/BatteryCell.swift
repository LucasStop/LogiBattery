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

    /// Todo aparelho com conexão usa o símbolo próprio com o selo no canto de baixo à direita (Symbols.xcassets,
    /// gerado por design/symbols/make.py, #65 e #75); o Mac (`laptop`) usa o SF Symbol do sistema, sem selo.
    var symbolName: String {
        switch (kind, path) {
        case (.laptop, _): "laptopcomputer"
        case (_, .bluetooth), (_, .receiver):
            "lb.\(kind.rawValue).\(path.rawValue)"
        case (.mouse, .internal): "computermouse"
        case (.keyboard, .internal): "keyboard"
        case (.headphones, .internal): "headphones"
        case (.other, .internal): "dot.radiowaves.left.and.right"
        }
    }

    var symbolHasBadge: Bool { symbolName.hasPrefix("lb.") }

    /// O selo vira parte do desenho, então a conexão vai no rótulo do VoiceOver.
    var symbol: Image {
        symbolHasBadge ? Image(symbolName, label: Text(path.labelKey)) : Image(systemName: symbolName)
    }
}
