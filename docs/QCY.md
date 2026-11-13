# QCY — protocolo do fone MeloBuds Pro

Referência do canal de controle BLE do QCY, medida no fone do Lucas. Complementa [ARCHITECTURE.md](ARCHITECTURE.md) §11.2 e as fixtures de `Tests/Fixtures/qcy/`.

Status: medido em 2026-11-12 (macOS 26), com o fone conectado ao Mac como dispositivo de áudio (A2DP). Leitura e escrita medidas no fone; o mapeamento de cenas de ANC foi confirmado de ouvido pelo Lucas, com o fone no ouvido, e restaurado ao estado original no fim.

## 1. O que isso resolve

O macOS mostra um número só para o fone, e o número que ele mostra não é o do fone: em 2026-11-12 o sistema exibia **100%** enquanto o advertising e a característica de bateria diziam **91–92%** em cada lado. O protocolo do QCY entrega o que o sistema não dá: bateria do lado esquerdo, do direito e do estojo, versão de firmware, modo de cancelamento de ruído, LDAC e modo jogo.

Implementação em [`LogiBattery/Core/BLE/`](../LogiBattery/Core/BLE): `QCYAdvertisement` (advertising), `QCYPacket` (framing), `QCYState` (estado acumulado) e `QCYClient` (CoreBluetooth). Protocolo documentado pelo projeto [Quicky](https://github.com/hui1601/Quicky) (`docs/protocol.md`), reimplementado a partir da descrição — o repositório não tem licença, então nenhum código foi copiado.

## 2. Descoberta

- Company id `0x521C` no manufacturer data. O `CoreBluetooth` entrega os dois bytes **em little-endian** no começo da `Data`.
- O advertising **não traz UUID de serviço** (`services=[]`), então filtrar o scan por serviço não acha o fone. O filtro é o company id, como o documento manda.
- Periférico conectado não anuncia: o cliente começa por `retrieveConnectedPeripherals(withServices: [A001])` e só então escaneia.

Advertising real (26 bytes), com o áudio ativo:

```
1c 52 4d 4a 9d 00 6e 5d 5e 00 b6 76 48 ac 84 60 6e 90 e9 01 ac 84 60 2f 9d e9
```

| Offset no payload | Campo | Valor medido |
|---|---|---|
| 0–1 | vendor id (BE) | `0x4D4A` (MeloBuds Pro; o documento mapeia id para modelo numa base de 199 produtos, que não copiamos) |
| 3 | color index | `(data[3] & 0x18) >> 1` |
| 5 / 6 / 7 | bateria esquerda / direita / estojo | `0x5D` (93%), `0x5E` (94%), `0x00` |
| 11–16 | control MAC | `84:AC:60:E9:90:6E` (igual ao MAC clássico pareado no macOS) |
| 18–23 | other MAC | `84:AC:60:E9:9D:2F` |

Ordem embaralhada do MAC: `[12]:[11]:[13]:[16]:[15]:[14]` a partir do primeiro byte do campo (mesma ordem para o other MAC). Bit 7 de cada byte de bateria é a flag de carga.

**Cuidado com os offsets.** O documento do Quicky conta do primeiro byte *depois* do company id; o `CoreBluetooth` inclui o company id. Ler o payload sem descartar os dois primeiros bytes desloca tudo e o MAC vira lixo — foi o que aconteceu na primeira tentativa.

## 3. GATT medido

| UUID | Modo | Uso |
|---|---|---|
| `0000a001` | serviço | Canal de controle do QCY |
| `00001001` | escrita | Comandos, com framing `0xFF` |
| `00001002` | leitura + notificação | Respostas e mudanças de estado |
| `00000008` | leitura + notificação | Bateria `[esquerda, direita, estojo]` |
| `00000007` | leitura | Versão `[a, b, c]` ou `[La, Lb, Lc, Ra, Rb, Rc]` |
| `0000000d` | leitura + escrita sem resposta | Funções das teclas (pares chave→função) |
| `0000000b` | leitura + escrita sem resposta | EQ (sem framing) |
| `00007033` | serviço extra | Características `1001`/`1002`/`2001`/`2002`, sem uso conhecido |

Detalhe que quebra escrita ingênua: `1001` anuncia **só escrita sem resposta** (props `4`). `writeValue(…, type: .withResponse)` falha calado nela; o cliente escolhe o tipo pela propriedade.

## 4. Framing

```
[0xFF] [tamanho do corpo] [comando 0x2C] [nº de parâmetros] [parâmetros...] [próximo comando] [...]
```

O tamanho do corpo é o total menos 2. Vários comandos cabem num pacote só.

Notificação real recebida em `00001002` ao assinar o canal (50 bytes, 12 comandos):

```
ff 30 2c 04 01 02 01 01 08 03 4f 4f 0f 09 01 02 17 03 03 02 00 10 01 00
16 01 32 04 01 02 23 01 00 24 01 01 1f 02 05 00 1d 02 08 0f 19 04 57 51 30 30
```

| Comando | Parâmetros | Leitura |
|---|---|---|
| `0x2C` detecção de uso | `01 02 01 01` | ligada; música=2, ANC=1, tom=1 |
| `0x08` volume | `4F 4F 0F` | esquerda/direita `0x4F`, máximo `0x0F` (semântica incerta, não modelada) |
| `0x09` modo jogo | `02` | desligado |
| `0x17` ANC | `03 02 00` | cena `0x03/0x02`, profundidade 0 |
| `0x10` repouso | `00` | desligado |
| `0x16` balanço | `32` | central |
| `0x04` música | `02` | pausada |
| `0x23` LDAC | `00` | desligado |
| `0x24` desconhecido | `01` | — |
| `0x1F` standby | `05 00` | — |
| `0x1D` volume do tom | `08 0F` | tom 8, máximo 15 |
| `0x19` idioma | `57 51 30 30` | "WQ00" |

O parser confere: 12 blocos, soma exata dos 48 bytes de corpo.

## 5. Comandos usados

| Comando | Envio | Resposta | Escrita funciona? |
|---|---|---|---|
| `0x2F` bateria | `FE 01 2F` (pedido) | `2F 03 esquerda direita estojo` | só leitura |
| `0x30` versão | `FE 01 30` | `30 03 a b c` ou `30 06 La Lb Lc Ra Rb Rc` | só leitura |
| `0x0C` modo simples | `0C 01 modo` (0 off, 1 ANC, 2 externo, 3 transparência) | **nada** (nem pedido com `0xFE` responde) | **não** — ver §7 |
| `0x17` cena de ANC | `17 03 modo cena profundidade` | igual, com normalização | **sim** |
| `0x09` modo jogo | `09 01 01` liga / `09 01 02` desliga | `09 01 01` / `09 01 02` | sim |
| `0x23` LDAC | `23 01 01` liga / `23 01 02` desliga | `23 01 00` / `23 01 01` | sim, persiste na reconexão |
| `0xFE` pedir valor | `FE 01 <comando>` | resposta do comando pedido | — |

Nos toggles o byte de resposta **não** é booleano: `0x01` = ligado, `0x02` = desligado no que se envia, mas a resposta do LDAC chega como `01 00`/`01 01` — a posição do valor muda entre pedido e resposta. O parser lê `parameters.first` porque é o que o fone manda de volta; não deduzir do que foi enviado.

O fone **não manda** o retrato sozinho em toda conexão: na primeira sonda mandou, nas seguintes ficou calado até receber `0xFE`. Por isso o cliente pede bateria, modo (`0x0C`), cena de ANC (`0x17`), LDAC e modo jogo ao terminar a descoberta. Pedir os dois (modo e cena) é inofensivo agora que são campos separados; neste modelo só o `0x17` responde.

## 6. Escrita medida

Toda escrita foi feita com o Lucas ao lado, com o fone nos ouvidos, e o estado devolvido ao original no fim.

| O que foi enviado | Eco do fone | Efeito |
|---|---|---|
| `0C 01 01` (modo ANC) | nenhum | nenhum — byte aceito e ignorado |
| `23 01 01` (LDAC on) | `23 01 01` | liga, persiste na reconexão |
| `23 01 00` (LDAC off) | `23 01 00` | desliga |
| `09 01 01` (jogo on) | `09 01 01` | liga |
| `09 01 02` (jogo off) | `09 01 02` | desliga |
| `17 03 01 02 03` | `17 03 01 02 03` | **ANC ligado** (confirmado de ouvido) |
| `17 03 02 02 00` | `17 03 02 00 00` | **normal/desligado** (confirmado de ouvido) — o fone normaliza a subcena para `00` |
| `17 03 03 02 00` | `17 03 03 02 00` | **transparência** (confirmado de ouvido) |

### Mapa de cenas (o `0x0C` é inútil neste modelo)

| Modo | Par `0x17` | Profundidade |
|---|---|---|
| ANC | `01/02` | `03` |
| Normal (desligado) | `02/00` | `00` |
| Transparência | `03/02` | `00` |

Depois de cada escrita de `0x17` o fone manda também `28 01 01`, um comando que **não está no mapa do Quicky** e cujo significado não foi medido. Não foi modelado.

A cena sobrevive à reconexão: escrever `02/00`, desconectar e reconectar devolve `17 03 02 00 00` na leitura. O mesmo vale para LDAC e modo jogo.

Trocar LDAC **derruba o link** por um instante (`desconectou: Unknown error`) e a bateria esquerda chega a aparecer como `0%` antes de voltar. É ruído da troca de codec, não perda de leitura: a leitura seguinte volta ao valor real.

## 7. O que o smoke provou

`tools/qcyctl/run.sh --seconds 12`, com o fone conectado como áudio:

```
advertising: vendor=0x4D4A L=91% R=92% estojo=- control=84:AC:60:E9:90:6E outr=84:AC:60:E9:9D:2F
bateria L=91% R=92% estojo=- · firmware 2.0.6 / 2.0.6
bateria L=91% R=92% estojo=- · firmware 2.0.6 / 2.0.6 · cena 03/02 · ldac off
bateria L=91% R=92% estojo=- · firmware 2.0.6 / 2.0.6 · cena 03/02 · jogo off · ldac off
```

Conclusão prática: **o fone aceita a conexão GATT de controle com o link de áudio ativo**. O app não precisa derrubar o áudio para ler a bateria, e o macOS mantém o vínculo clássico em paralelo.

## 8. Limites e riscos

- **Estojo sem leitura** reporta `0x00`, não 0%. O modelo trata como ausência de dado; o documento não define o caso.
- **`0x0C` é escrita morta neste modelo.** Pedido com `0xFE` não responde e escrita não muda nada. Não foi removido do cliente (outros modelos QCY podem usá-lo), mas não deve ser enviado junto com `0x17`: as duas respostas caíam no mesmo campo e o estado oscilava entre `2/0` e `3/2`. Hoje são campos separados (`noiseCancelMode` e `ancScene`), com teste de regressão.
- **`0x28` fora do mapa.** Depois de cada `0x17` chega `28 01 01`; não modelado.
- **Normalização de subcena**: pedir `02/02` no modo normal devolve `02/00`. Escrever a cena e reler é a única forma de saber o que o fone aceitou de fato.
- **Base de produtos não copiada**: o Quicky baixa 199 modelos da API da QCY. Nada disso entra aqui; só o vendor id medido, em hex.
- **O app da QCY no celular compete pelo vínculo.** Se ele estiver aberto, o fone pode aparecer como `-APP` e o comportamento de advertising muda.

## 9. Como reproduzir

```bash
tools/qcyctl/run.sh --seconds 12                                    # leitura
tools/qcyctl/run.sh --seconds 12 --scene 01/02/03 --verbose          # ANC
tools/qcyctl/run.sh --seconds 12 --scene 02/00/00 --verbose          # normal
tools/qcyctl/run.sh --seconds 12 --scene 03/02/00 --verbose          # transparência
tools/qcyctl/run.sh --seconds 12 --ldac off --low-latency off         # restaurar toggles
```

O script compila `tools/qcyctl/main.swift` junto com `LogiBattery/Core/BLE/*.swift` e roda dentro de um `.app` assinado ad-hoc em `$TMPDIR/qcyctl`. O bundle é obrigatório: um binário de linha de comando sem `NSBluetoothAlwaysUsageDescription` morre com `SIGABRT` (exit 134) assim que toca no `CBCentralManager`, e o relatório de crash aponta o TCC, não o código. Foi o primeiro tropeço desta etapa.
