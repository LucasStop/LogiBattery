import AppKit
import CoreText
import Foundation

/// Renderiza o ícone de bateria da barra de menus no estilo nativo da Apple:
/// geometria medida no `BatteryUIKit` (`29 × 14 pt`, sem folga à direita), dígitos em **SF Pro Rounded Bold**
/// centralizados dentro do corpo e estados de carga/Pouca Energia/baixa/crítica.
enum MenuBarBatteryIcon {
    static let size = NSSize(width: 29, height: 14)

    struct Style: Equatable, Sendable {
        let percent: Int?
        let isCharging: Bool
        let isPluggedFull: Bool
        let isLowPowerMode: Bool
        let level: BatteryLevel
        let hasLoaded: Bool

        /// Nativo: colorido só em Pouca Energia (amarelo) e baixa/crítica (vermelho);
        /// carregando ou plugado fica monocromático.
        var usesColor: Bool {
            percent != nil && (isLowPowerMode || level == .low || level == .critical)
        }

        /// O raio do nativo aparece carregando e plugado em 100%.
        var showsBolt: Bool { isCharging || isPluggedFull }
    }

    static func image(for style: Style) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            draw(style: style)
            return true
        }
        image.isTemplate = !style.usesColor
        return image
    }

    private static func draw(style: Style) {
        let bodyRect = NSRect(x: 0.5, y: 0.5, width: 26, height: 13)
        let bodyRadius: CGFloat = 4.6
        let capRect = NSRect(x: 27.4, y: 4.8, width: 1.5, height: 4.4)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: bodyRadius, yRadius: bodyRadius)
        let capPath = NSBezierPath(roundedRect: capRect, xRadius: 0.75, yRadius: 0.75)

        let fraction = CGFloat(min(max(style.percent ?? 0, 0), 100)) / 100.0
        let fillColor = resolvedFillColor(for: style)
        let trackColor: NSColor = style.usesColor
            ? NSColor.gray.withAlphaComponent(0.42)
            : NSColor.black.withAlphaComponent(0.38)

        // Trilha de fundo do corpo
        trackColor.setFill()
        bodyPath.fill()

        // Preenchimento proporcional dentro do corpo
        if style.percent != nil, fraction > 0 {
            NSGraphicsContext.saveGraphicsState()
            bodyPath.addClip()
            fillColor.setFill()
            let fillWidth = max(bodyRect.width * fraction, 2.0)
            NSRect(x: bodyRect.minX, y: bodyRect.minY, width: fillWidth, height: bodyRect.height).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        // Borda sutil para manter definição sobre fundos claros ou translúcidos
        let borderColor: NSColor = style.usesColor
            ? NSColor.gray.withAlphaComponent(0.28)
            : NSColor.black.withAlphaComponent(0.25)
        borderColor.setStroke()
        bodyPath.lineWidth = 0.5
        bodyPath.stroke()

        // Polo positivo à direita (cápsula semicircular)
        let capColor: NSColor = (style.percent == 100) ? fillColor : trackColor
        capColor.setFill()
        capPath.fill()

        // Número em SF Pro Rounded Bold (e raio interno quando carregando) centralizados no corpo
        let label = labelText(for: style)
        drawCenteredContent(label, in: bodyRect, style: style)
    }

    private static func resolvedFillColor(for style: Style) -> NSColor {
        guard style.usesColor else { return .black }
        if style.level == .critical || style.level == .low {
            return NSColor(calibratedRed: 1.0, green: 0.231, blue: 0.188, alpha: 1) // Apple systemRed #FF3B30
        }
        return NSColor(calibratedRed: 1.0, green: 0.800, blue: 0.0, alpha: 1) // Apple systemYellow #FFCC00
    }

    private static func labelText(for style: Style) -> String {
        if let percent = style.percent { return "\(percent)" }
        return style.hasLoaded ? "!" : "…"
    }

    private static func roundedBoldFont(ofSize size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .bold)
        if let rounded = base.fontDescriptor.withDesign(.rounded),
           let font = NSFont(descriptor: rounded, size: size) {
            return font
        }
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
    }

    private static func drawCenteredContent(_ text: String, in rect: NSRect, style: Style) {
        let isThreeDigits = text.count >= 3
        let fontSize: CGFloat = style.showsBolt
            ? (isThreeDigits ? 8.6 : 9.8)
            : (isThreeDigits ? 9.2 : 10.6)
        let font = roundedBoldFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: isThreeDigits ? -0.45 : -0.1,
            .foregroundColor: labelColor(for: style)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()

        let boltWidth: CGFloat = style.showsBolt ? 4.8 : 0
        let boltGap: CGFloat = style.showsBolt ? 1.0 : 0
        let totalWidth = textSize.width + boltGap + boltWidth
        let startX = rect.midX - totalWidth / 2

        // Centra a tinta real dos glifos (CTLineGetImageBounds), não a caixa da linha: dá o mesmo resultado em
        // qualquer tamanho de fonte e para "!" e "…".
        let line = CTLineCreateWithAttributedString(attributed)
        let ink = CTLineGetImageBounds(line, nil)

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext.current?.cgContext {
            if !style.usesColor { context.setBlendMode(.clear) }
            context.textPosition = CGPoint(x: startX, y: rect.midY - ink.midY)
            CTLineDraw(line, context)
        }
        NSGraphicsContext.restoreGraphicsState()

        if style.showsBolt {
            let boltRect = NSRect(
                x: startX + textSize.width + boltGap,
                y: rect.midY - 4.0,
                width: boltWidth,
                height: 8.0
            )
            drawBolt(in: boltRect, color: labelColor(for: style), knockOut: !style.usesColor)
        }
    }

    private static func labelColor(for style: Style) -> NSColor {
        guard style.usesColor else { return .black }
        return style.level == .low || style.level == .critical ? .white : .black
    }

    private static func drawBolt(in rect: NSRect, color: NSColor, knockOut: Bool) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + rect.width * 0.62, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.44))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.44))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.36, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.92, y: rect.minY + rect.height * 0.56))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.56))
        path.close()
        NSGraphicsContext.saveGraphicsState()
        if knockOut { NSGraphicsContext.current?.cgContext.setBlendMode(.clear) }
        color.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
