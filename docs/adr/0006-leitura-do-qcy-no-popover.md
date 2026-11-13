# ADR 0006 — Leitura de bateria do QCY no popover (L/R), controle só no app separado

- Status: proposta (aguarda aprovação do Lucas e do protótipo T13)
- Data: 2026-11-13

## Contexto
O popover mostra o MeloBuds Pro com "—": o macOS não informa nível a este fone (e, quando informou, errou: 100% com o fone em 91-92%). O protocolo QCY já está medido e implementado em `Core/BLE` ([QCY.md](../QCY.md)) e o app QCYBattery (ADR 0005, #135) usa esse módulo para ler e escrever. O Lucas pediu uma linha só no popover com os dois lados separados ("L 90% · R 85%"). O estojo não é exposto pelo firmware 2.0.6: byte `0x00` com tampa aberta ou fechada.

## Decisão
- O LogiBattery passa a **ler** bateria L/R do QCY e mostrar numa linha única. Nenhuma escrita no fone a partir do LogiBattery: ANC, LDAC e modo jogo ficam no QCYBattery.
- Fonte preferida: advertising `0x521C` (não conecta, não compete com o QCYBattery nem com o app do celular); GATT só se o advertising não vier.
- `Device` ganha `sides` opcional e aditivo; `percent` é o **menor lado**, então regra de bateria baixa, ícone da barra de menu, histórico e widget funcionam sem mudança. `snapshot.json` mantém `schemaVersion` 1 (campo opcional).
- A linha `bt-audio-<nome>` do IOBluetooth e a linha do QCY fundem por nome (`DeviceDeduplicator`).
- Estojo: não aparece enquanto `caseBattery == nil`; entra como terceiro item se algum firmware reportar.

## Alternativas consideradas
- Duas linhas (L e R): o Lucas escolheu uma linha só.
- Só o menor lado, sem detalhe: esconde a diferença entre os lados.
- Deixar só no app QCYBattery: o popover continuaria com "—".

## Consequências
- Positivas: bateria real do fone no popover, no ícone e no widget, sem "100%" falso.
- Riscos: mais um leitor Bluetooth no host; com o fone no estojo fechado nada anuncia (linha cinza). Se o advertising não bastar, dois clientes GATT (LogiBattery e QCYBattery) no mesmo fone precisam ser medidos.
- Testes: parsers já cobertos por `QCYProtocolTests`; novo: merge/dedupe, menor lado, `sides` no `SnapshotContractTests`, linha em `DeviceListViewModelTests` com leitor falso.
