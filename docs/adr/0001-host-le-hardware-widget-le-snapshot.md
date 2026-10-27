# ADR 0001 — App host lê o hardware; widget só lê o snapshot

- Status: proposta
- Data: 2026-10-27

## Contexto
O widget do macOS roda em extensão sandboxed e não acessa IOKit/HID. A bateria só se obtém falando HID++ com o receptor, o que exige Input Monitoring e um processo vivo. O widget precisa de dados frescos sem fazer a leitura.

## Decisão
Um app host de barra de menu (`LSUIElement`) é o único que acessa o hardware. Ele grava um `snapshot.json` e o histórico no container do App Group e pede `WidgetCenter.shared.reloadAllTimelines()` a cada leitura. A extensão de widget só lê o snapshot.

## Alternativas consideradas
- Widget lendo o hardware direto: impossível, a extensão não acessa HID.
- Helper separado (XPC/LaunchAgent): mais peças e assinatura mais complexa sem ganho para uso pessoal; reavaliar na distribuição.
- Depender do Logi Options+ para a leitura: exige software de terceiros rodando e conta; fora do objetivo.

## Consequências
- Positivas: separação clara; widget simples e testável pelo contrato do snapshot; permissão concentrada em um app.
- Negativas e riscos: sem o app rodando o widget fica desatualizado; o widget mostra a hora da última leitura para deixar isso explícito.
- Impacto em testes e design: contrato do snapshot testado (`SnapshotContractTests`); estado "desatualizado" entra no design do widget.
