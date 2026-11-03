# ADR 0002 — Bateria do Mac e do fone Bluetooth pelo próprio macOS

- Status: aceita (aprovada pelo Lucas em 2026-11-03)
- Data: 2026-11-03

## Contexto
O Lucas quer usar só o widget do LogiBattery e dispensar o widget "Baterias" da Apple, que mostra também a bateria do Mac e a do fone Bluetooth (US-13). Nenhum dos dois fala HID++: a bateria do Mac é do sistema, e a do fone chega ao macOS pelo perfil Bluetooth (HFP), não por um protocolo que o app leia.

## Decisão
- Mac: `IOPSCopyPowerSourcesInfo` / `IOPSGetPowerSourceDescription` (API pública), só a fonte `InternalBattery`. Percentual é `Current Capacity * 100 / Max Capacity`; `Is Charging` vira carregando e `Is Charged` vira cheio.
- Fone: `IOBluetoothDevice.pairedDevices()`, conectados e de classe major áudio (`0x04`), lendo por KVC as chaves privadas `batteryPercentSingle`, `batteryPercentCombined`, `batteryPercentLeft` e `batteryPercentRight` (zero é "sem dado"). É de onde a Central de Controle tira o mesmo número.
- As duas leituras entram no `LiveScanner` junto da leitura HID++, no mesmo ciclo (padrão 1 min); o IOBluetooth roda na main.
- Fone fora da leitura some na hora: o sistema sabe se ele está conectado, então não vale a regra das 24 h do aparelho dormindo.

## Alternativas consideradas
- `system_profiler SPBluetoothDataType -json` (`device_batteryLevelMain`): abre processo a cada leitura (1 a 2 s) e o sandbox do app bloqueia executar binário.
- `ioreg` / `BatteryPercent` no IORegistry: só aparece para acessório Apple (Magic Mouse, Magic Keyboard); o fone de terceiros não tem.
- Não mostrar fone: o Lucas manteria o widget da Apple ao lado, que é o que ele quer evitar.

## Consequências
- Positivas: um widget só para todos os aparelhos; sem processo novo, sem rede, sem permissão além da de Bluetooth (`NSBluetoothAlwaysUsageDescription`, entitlement `device.bluetooth` já existente).
- Negativas e riscos: chave privada pode sumir numa versão do macOS; o efeito é o fone sumir da lista, sem quebrar o resto. Uso pessoal aceita o risco; na distribuição (issue #24) reavaliar.
- Impacto em testes e design: lógica pura testada com o dicionário real do `IOPowerSources` e níveis do fone (`SystemBatteriesTests`); leitura real só no smoke manual. `kind` ganha `laptop` e `headphones`, `path` ganha `internal` (sem selo de caminho no widget).
