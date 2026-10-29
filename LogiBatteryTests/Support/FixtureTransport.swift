import Foundation
@testable import LogiBattery

/// Reproduz frames gravados em `Tests/Fixtures/hidpp/*.txt` (linhas `> pedido` e `< resposta`).
struct FixtureTransport: HIDPPTransport {
    private let replies: [[UInt8]: [UInt8]]

    /// `patch` altera as respostas gravadas (ex.: simular carregando, que não temos gravado).
    init(fixture name: String, patch: (inout [UInt8]) -> Void = { _ in }) throws {
        let url = try XCTUnwrapFixture(name)
        var replies: [[UInt8]: [UInt8]] = [:]
        var pending: [UInt8]?
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
            let bytes = line.dropFirst(2).split(separator: " ").compactMap { UInt8($0, radix: 16) }
            if line.hasPrefix("> ") { pending = bytes } else if line.hasPrefix("< "), let request = pending {
                var reply = bytes
                patch(&reply)
                replies[request] = reply
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
