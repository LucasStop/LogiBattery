# ADR 0005 — Protocolo do fone QCY em módulo próprio, somente leitura

- Status: aceita (escopo F4 escolhido pelo Lucas em 2026-11-12; ligar na interface ficou pendente)
- Data: 2026-11-12

## Contexto
O teclado e o mouse entram por HID++ e o fone Bluetooth por `IOBluetooth` (ADR 0002). O fone do Lucas, um QCY MeloBuds Pro, expõe um canal de controle GATT proprietário com muito mais do que o macOS mostra: bateria do lado esquerdo, do direito e do estojo, firmware, modo de cancelamento de ruído, LDAC e modo jogo. O macOS mostra um número só — e em 2026-11-12 mostrava 100% enquanto o fone reportava 91–92%. O PRD hoje lista "protocolo proprietário de outra marca" como fora de escopo, e o repositório que documenta o protocolo (Quicky) não tem licença.

## Decisão
- Cliente próprio escrito a partir da **descrição** do protocolo em `docs/protocol.md` do Quicky. Nenhum código foi copiado: o repositório não tem licença.
- Módulo isolado em `LogiBattery/Core/BLE` (`QCYAdvertisement`, `QCYPacket`, `QCYState`, `QCYClient`), dependendo só de Foundation e CoreBluetooth, sem tocar no modelo de `Device`.
- **Somente leitura** no escopo do módulo. Bateria, firmware, ANC, LDAC e jogo saem de notificação e de pedido `0xFE`. Escrita existe no cliente (`setLDAC`, `setLowLatency`, `ancSetting`), foi exercitada uma vez no hardware com o Lucas presente e o estado restaurado no fim — achados em `docs/QCY.md` §6. O módulo continua sem expor escrita para a interface.
- `tools/qcyctl` para smoke manual, reaproveitando os mesmos arquivos do app.
- Nada é ligado à lista de aparelhos, ao widget ou ao histórico antes de uma decisão de produto: bateria por lado não cabe no modelo de um número só, e o PRD precisa de história nova (ou alvo separado).

## Alternativas consideradas
- Depender do que o macOS mostra: um número, e nesse dia errado.
- Copiar o Quicky (Go): resolveria em uma tarde e criaria dívida de licença.
- Engenharia reversa de firmware: fora de escopo desde o começo.

## Consequências
- Positivas: o que o sistema não dá passa a existir no repositório, com protocolo medido e fixtures reais; o fone aceita GATT com o áudio ativo, então não é preciso derrubar o som para ler.
- Negativas e riscos: mais uma superfície de TCC e um vínculo GATT a mais; o app da QCY no celular compete pelo vínculo e muda o advertising; a cena de ANC (`0x17`) é a única via real de troca de modo neste modelo — o `0x0C` não responde; escrita mexe no estado de quem está usando o fone, então só entra com o Lucas presente e um modo de voltar combinado.
- Impacto em testes: parsers cobertos por `QCYProtocolTests` com bytes gravados; CoreBluetooth não roda no CI, então o vínculo real fica no smoke manual.
