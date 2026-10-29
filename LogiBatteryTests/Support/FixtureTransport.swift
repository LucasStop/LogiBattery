import Foundation
@testable import LogiBattery

/// Reproduz frames gravados em `Tests/Fixtures/hidpp/*.txt` (linhas `> pedido` e `< resposta`).
struct FixtureTransport: HIDPPTransport {
    private let replies: [[UInt8]: [UInt8]]

    init(fixture name: String) throws {
        let url = try XCTUnwrapFixture(name)
        var replies: [[UInt8]: [UInt8]] = [:]
        var pending: [UInt8]?
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
            let bytes = line.dropFirst(2).split(separator: " ").compactMap { UInt8($0, radix: 16) }
            if line.hasPrefix("> ") { pending = bytes } else if line.hasPrefix("< "), let request = pending {
                replies[request] = bytes
            }
        }
        self.replies = replies
    }

    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame {
        guard let bytes = replies[request.bytes] else { throw HIDPPError.noDevice }
        guard let frame = HIDPPFrame(response: bytes) else { throw HIDPPError.malformed }
        return frame
    }
}

private func XCTUnwrapFixture(_ name: String) throws -> URL {
    let bundle = Bundle(for: FixtureBundleMarker.self)
    guard let url = bundle.url(forResource: name, withExtension: "txt") else {
        throw HIDPPError.noDevice
    }
    return url
}

private final class FixtureBundleMarker {}
