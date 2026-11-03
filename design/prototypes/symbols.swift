// Gera symbols.js com os SF Symbols de verdade para os protótipos (o navegador não desenha SF Symbol).
// Uso: swift design/prototypes/symbols.swift > design/prototypes/symbols.js
// Cada símbolo sai em PNG 3x no tamanho de 24 pt, embutido em data URI: máscara CSS por arquivo falha em file://.
import AppKit

let names = [("laptop", "laptopcomputer"), ("keyboard", "keyboard"), ("mouse", "computermouse"),
             ("headphones", "headphones"), ("plug", "cable.connector"), ("bolt", "bolt.fill")]
let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
var entries: [String] = []
for (key, name) in names {
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config),
          let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * 3),
                                     pixelsHigh: Int(image.size.height * 3), bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                     bitsPerPixel: 0)
    else { fatalError("símbolo \(name) não existe") }
    rep.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: image.size))
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!.base64EncodedString()
    let size = String(format: "w:%.2f,h:%.2f", image.size.width, image.size.height)
    entries.append(" \(key):{\(size),d:'data:image/png;base64,\(png)'}")
}
print("// Gerado por symbols.swift a partir dos SF Symbols (tamanho em pt a 24 pt). Não editar à mão.")
print("const SF={\n\(entries.joined(separator: ",\n"))};")
