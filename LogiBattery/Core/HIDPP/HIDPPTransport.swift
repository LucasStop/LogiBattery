/// Troca de um pedido por sua resposta. Real: `IOHIDTransport`; testes: frames gravados.
protocol HIDPPTransport: Sendable {
    func exchange(_ request: HIDPPFrame) async throws -> HIDPPFrame
}
