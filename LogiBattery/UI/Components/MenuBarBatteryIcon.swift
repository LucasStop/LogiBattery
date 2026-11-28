import AppKit
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

        var usesColor: Bool {
            percent != nil && (isCharging || isPluggedFull || isLowPowerMode || level == .low || level == .critical)
        }
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
        let bodyRect = NSRect(x: 0.5, y: 0.75, width: 25.5, height: 12.5)
        let bodyRadius: CGFloat = 3.2
        let capRect = NSRect(x: 27.0, y: 4.9, width: 1.5, height: 4.2)
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
        if style.isCharging || style.isPluggedFull {
            return NSColor(calibratedRed: 0.204, green: 0.780, blue: 0.349, alpha: 1) // Apple systemGreen #34C759
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
        let fontSize: CGFloat = style.isCharging
            ? (isThreeDigits ? 7.6 : 8.8)
            : (isThreeDigits ? 8.2 : 9.5)
        let font = roundedBoldFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: isThreeDigits ? -0.45 : -0.1,
            .foregroundColor: labelColor(for: style)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()

        let boltWidth: CGFloat = style.isCharging ? 4.4 : 0
        let boltGap: CGFloat = style.isCharging ? 1.0 : 0
        let totalWidth = textSize.width + boltGap + boltWidth
        let startX = rect.midX - totalWidth / 2

        let drawRect = NSRect(
            x: startX,
            y: rect.midY - textSize.height / 2 + 0.25,
            width: textSize.width,
            height: textSize.height
        )

        NSGraphicsContext.saveGraphicsState()
        if !style.usesColor, let context = NSGraphicsContext.current?.cgContext {
            context.setBlendMode(.clear)
        }
        attributed.draw(in: drawRect)
        NSGraphicsContext.restoreGraphicsState()

        if style.isCharging {
            let boltRect = NSRect(
                x: startX + textSize.width + boltGap,
                y: rect.midY - 3.7,
                width: boltWidth,
                height: 7.4
            )
            drawBolt(in: boltRect, color: labelColor(for: style))
        }
    }

    private static func labelColor(for style: Style) -> NSColor {
        guard style.usesColor else { return .black }
        if style.isLowPowerMode && style.level != .low && style.level != .critical
            && !style.isCharging && !style.isPluggedFull {
            return .black
        }
        return .white
    }

    private static func drawBolt(in rect: NSRect, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + rect.width * 0.62, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.44))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.44))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.36, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.92, y: rect.minY + rect.height * 0.56))
        path.line(to: NSPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.56))
        path.close()
        color.setFill()
        path.fill()
    }
}
