import Foundation

enum QCYFixtureError: Error {
    case missing(String)
}

/// Lê uma fixture de hex de `Tests/Fixtures/qcy/`. Linhas começando com `#` são comentário.
func qcyFixture(_ name: String) throws -> [UInt8] {
    let bundle = Bundle(for: QCYFixtureMarker.self)
    guard let url = bundle.url(forResource: name, withExtension: "txt") else {
        throw QCYFixtureError.missing(name)
    }
    var bytes: [UInt8] = []
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        let text = line.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !text.hasPrefix("#") else { continue }
        bytes += text.split(separator: " ").compactMap { UInt8($0, radix: 16) }
    }
    guard !bytes.isEmpty else { throw QCYFixtureError.missing(name) }
    return bytes
}

private final class QCYFixtureMarker {}
