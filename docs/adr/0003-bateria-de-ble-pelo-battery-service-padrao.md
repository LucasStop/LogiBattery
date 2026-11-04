# ADR 0003 — Bateria de teclado e mouse BLE de qualquer marca pelo Battery Service padrão

- Status: aceita (plano aprovado pelo Lucas em 2026-11-04)
- Data: 2026-11-04

## Contexto
O Lucas quer ver todos os teclados e mouses no widget, não só Logitech. O teclado BLE KF8700 (Hailuck) mostra 90% em Ajustes > Bluetooth, mas não tem `BatteryPercent` no IORegistry, as chaves privadas `batteryPercent*` do `IOBluetoothDevice` voltam 0 e o `system_profiler` não lista nível (#121). O nível vem do Battery Service BLE padrão (GATT `0x180F`, característica `0x2A19`), que quase todo teclado e mouse BLE implementa.

## Decisão
- `CoreBluetooth` (API pública): `retrieveConnectedPeripherals(withServices: [0x180F])`, conecta se preciso, descobre `0x2A19` e lê o primeiro byte (0 a 100). Provado com o KF8700 (90) e o MX Master 3S (85).
- `BLEBatteryReader` roda numa fila própria, tem timeout de 4 s por leitura e devolve vazio sem permissão, sem Bluetooth ou sem resposta.
- A leitura entra em `SystemBatteries.read` com id `bt-ble-<nome>`, `path: .bluetooth`, e passa pelo `DeviceDeduplicator`: HID++ do mesmo aparelho vence a leitura genérica, como já vale para `bt-*`.
- Sem permissão nova: `NSBluetoothAlwaysUsageDescription` e o entitlement `device.bluetooth` já existem (ADR 0002).

## Alternativas consideradas
- Chaves privadas do `IOBluetoothDevice`: devolvem 0 para esse teclado e para o MX.
- `system_profiler`: não traz nível e abre processo a cada leitura.
- Protocolo proprietário de cada marca: inviável para "todas as marcas".

## Consequências
- Positivas: qualquer aparelho BLE com Battery Service aparece sem código por marca; só API pública.
- Negativas e riscos: aparelho sem Battery Service (ou só com Bluetooth clássico) continua de fora. A primeira conexão do app ao periférico pode atrasar a primeira leitura. O app mantém uma conexão GATT aberta com o periférico, que o sistema já mantém conectado.
- Impacto em testes: `bleDevice` testado em `SystemBatteriesTests`; leitura real só no smoke manual com o KF8700.
