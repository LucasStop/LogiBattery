# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), em português, uma seção por versão publicada (ADR 0007). Cada PR `feat` ou `fix` traz a própria seção, com o que mudou e por quê; os demais tipos não entram. Seções: Adicionado, Alterado, Corrigido, Removido.

## 0.3.0 - 2026-11-13

Acumula tudo o que entrou na main desde a 0.2.0 (04/11), que ficou sem versão porque o PR de release separado não foi rodado (ADR 0007). A partir daqui cada PR `feat` ou `fix` traz a própria versão.

### Adicionado

- Popover mostra o fone QCY MeloBuds Pro com bateria do lado esquerdo, do direito e, quando o firmware reportar, do estojo (#142). O macOS devolvia "—" ou um 100% errado para o fone. O anel do topo é dividido ao meio (L e R) com um tooltip do estojo, e a linha da lista traz "L 90% · R 85%". O ícone da barra, o histórico, o aviso de bateria baixa e o widget usam o menor lado, então nada mudou neles. O LogiBattery só lê o fone; controle continua no QCYBattery (ADR 0006).
- App separado QCYBattery para o fone QCY, com bateria por lado e controle de cancelamento de ruído, LDAC e modo jogo (#135), mais scheme e ícone próprios (#140). Fica fora do LogiBattery porque o protocolo é de outra marca e escreve no fone (ADR 0005).
- Leitura da bateria e do estado do fone por BLE GATT, com o protocolo medido em `docs/QCY.md`.
- Leitura da tabela de features HID++ de cada aparelho, para saber o que cada mouse e teclado expõe (`docs/HIDPP.md`).
- Escrita HID++ de DPI e SmartShift em `--dry-run` por padrão, só grava com `--apply` e confere o valor lido depois (#137). Fica atrás do dry-run até definir quem manda no receptor Bolt com o Options+ aberto.

### Corrigido

- Modo de ruído e cena de ANC do fone eram guardados no mesmo campo e o valor oscilava conforme a ordem das respostas; agora são separados (`0x0C` e `0x17`).
- Compilação do QCYBattery quebrava no Xcode do CI (crash do compilador com referência a método em `@MainActor`); as ações da janela usam closures explícitas.

## 0.2.0 - 2026-11-04

### Novidades

- version scripts, release script and CI tag check (a533dbe)
- battery of any BLE keyboard or mouse via the Battery Service (6866659)
- adjustable gray, forget and keep rules for unresponsive devices (05bf2f5)
- forget a kept device from the row context menu (9c7eb6a)
- use cropped prototype shots per theme and fix landmark and heading order (4751422)
- add the first-launch install notice (16e5a88)

### Correções

- keep next-version.sh alive when a release has no fix commits (ba86b36)
- one rule for kept, gray and gone devices, with an injected clock (edc7931)
