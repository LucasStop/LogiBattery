import SwiftUI
import XCTest
@testable import LogiBattery

/// Símbolo por aparelho e conexão (#65): mouse, teclado e fone levam o selo dentro do desenho (`lb.*`, catálogo
/// Symbols.xcassets); o resto usa o SF Symbol do sistema e o selo separado.
final class DeviceSymbolTests: XCTestCase {
    private func device(_ kind: DeviceKind, _ path: DevicePath) -> Device {
        Device(id: "x", name: "x", kind: kind, percent: 50, chargeState: .discharging, path: path, readAt: .now)
    }

    func testSymbolTable() {
        // swiftlint:disable:next large_tuple
        let table: [(DeviceKind, DevicePath, String)] = [
            (.mouse, .bluetooth, "lb.mouse.bluetooth"),
            (.mouse, .receiver, "lb.mouse.receiver"),
            (.keyboard, .bluetooth, "lb.keyboard.bluetooth"),
            (.keyboard, .receiver, "lb.keyboard.receiver"),
            (.headphones, .bluetooth, "lb.headphones.bluetooth"),
            (.headphones, .receiver, "headphones"),
            (.laptop, .internal, "laptopcomputer"),
            (.other, .bluetooth, "dot.radiowaves.left.and.right"),
            (.other, .receiver, "dot.radiowaves.left.and.right")
        ]
        for (kind, path, name) in table {
            XCTAssertEqual(device(kind, path).symbolName, name, "\(kind) \(path)")
            XCTAssertEqual(device(kind, path).symbolHasBadge, name.hasPrefix("lb."), "\(kind) \(path)")
        }
    }

    /// Todo `lb.*` da tabela precisa existir no catálogo, senão a imagem sai vazia sem erro.
    func testCustomSymbolsExistInCatalog() {
        for name in ["lb.mouse.bluetooth", "lb.mouse.receiver", "lb.keyboard.bluetooth", "lb.keyboard.receiver",
                     "lb.headphones.bluetooth"] {
            XCTAssertNotNil(NSImage(named: name), name)
        }
    }

    /// Regressão da #74: sem o glifo da escala, o símbolo sai vazio (o popover usa a pequena).
    @MainActor
    func testCustomSymbolsDrawInEveryScale() throws {
        for name in ["lb.mouse.bluetooth", "lb.mouse.receiver", "lb.keyboard.bluetooth", "lb.keyboard.receiver",
                     "lb.headphones.bluetooth"] {
            for scale in [Image.Scale.small, .medium, .large] {
                let view = Image(name).imageScale(scale).font(.system(size: 24)).foregroundStyle(.black)
                    .frame(width: 64, height: 64)
                let renderer = ImageRenderer(content: view)
                let image = try XCTUnwrap(renderer.cgImage)
                XCTAssertGreaterThan(inkedPixels(image), 20, "\(name) \(scale)")
            }
        }
    }

    private func inkedPixels(_ image: CGImage) -> Int {
        let rep = NSBitmapImageRep(cgImage: image)
        return (0..<rep.pixelsWide).reduce(0) { sum, column in
            sum + (0..<rep.pixelsHigh).filter { (rep.colorAt(x: column, y: $0)?.alphaComponent ?? 0) > 0.5 }.count
        }
    }
}
