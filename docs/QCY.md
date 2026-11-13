# QCY — protocolo do fone MeloBuds Pro

Referência do canal de controle BLE do QCY, medida no fone do Lucas. Complementa [ARCHITECTURE.md](ARCHITECTURE.md) §11.2 e as fixtures de `Tests/Fixtures/qcy/`.

Status: medido em 2026-11-12 (macOS 26), com o fone conectado ao Mac como dispositivo de áudio (A2DP). Somente leitura; nenhum ajuste foi escrito no fone.

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

| Comando | Envio | Resposta |
|---|---|---|
| `0x2F` bateria | `FE 01 2F` (pedido) | `2F 03 esquerda direita estojo` |
| `0x30` versão | `FE 01 30` | `30 03 a b c` ou `30 06 La Lb Lc Ra Rb Rc` |
| `0x0C` modo simples | `0C 01 modo` (0 off, 1 ANC, 2 externo, 3 transparência) | `0C 01 modo` |
| `0x17` cena de ANC | `17 03 modo cena profundidade` | igual |
| `0x09` modo jogo | `09 01 01` liga / `09 01 02` desliga | igual |
| `0x23` LDAC | `23 01 01` liga / `23 01 02` desliga | igual |
| `0xFE` pedir valor | `FE 01 <comando>` | resposta do comando pedido |

O fone **não manda** o retrato sozinho em toda conexão: na primeira sonda mandou, nas seguintes ficou calado até receber `0xFE`. Por isso o cliente pede bateria, ANC (`0x0C` e `0x17`), LDAC e modo jogo ao terminar a descoberta.

## 6. O que o smoke provou

`tools/qcyctl/run.sh --seconds 12`, com o fone conectado como áudio:

```
advertising: vendor=0x4D4A L=91% R=92% estojo=- control=84:AC:60:E9:90:6E outr=84:AC:60:E9:9D:2F
bateria L=91% R=92% estojo=- · firmware 2.0.6 / 2.0.6
bateria L=91% R=92% estojo=- · firmware 2.0.6 / 2.0.6 · anc cena 0x03/02 [3/2] · ldac off
bateria L=91% R=92% estojo=- · firmware 2.0.6 / 2.0.6 · anc cena 0x03/02 [3/2] · jogo off · ldac off
```

Conclusão prática: **o fone aceita a conexão GATT de controle com o link de áudio ativo**. O app não precisa derrubar o áudio para ler a bateria, e o macOS mantém o vínculo clássico em paralelo.

## 7. Limites e riscos

- **Estojo sem leitura** reporta `0x00`, não 0%. O modelo trata como ausência de dado; o documento não define o caso.
- **Cena de ANC ambígua**: o documento dá `0x03/0x02` como "ambiente de trabalho nível 2" na tabela de cenas e como transparência no remapeamento do app. O fone medido reporta exatamente `3/2`. Nenhum nome é inventado: sai `cena 0x03/02`. Resolver com um experimento controlado — trocar de modo no app da QCY e ver o valor cru mudar.
- **Escrita não exercitada**: `--anc`, `--ldac` e `--low-latency` existem no cliente e têm bytes conferidos em teste, mas nenhuma escrita foi feita no fone. Escrita muda o estado de quem está usando o fone; só com o Lucas presente e um modo de voltar.
- **Base de produtos não copiada**: o Quicky baixa 199 modelos da API da QCY. Nada disso entra aqui; só o vendor id medido, em hex.
- **O app da QCY no celular compete pelo vínculo.** Se ele estiver aberto, o fone pode aparecer como `-APP` e o comportamento de advertising muda.

## 8. Como reproduzir

```bash
tools/qcyctl/run.sh --seconds 12
```

O script compila `tools/qcyctl/main.swift` junto com `LogiBattery/Core/BLE/*.swift` e roda dentro de um `.app` assinado ad-hoc em `$TMPDIR/qcyctl`. O bundle é obrigatório: um binário de linha de comando sem `NSBluetoothAlwaysUsageDescription` morre com `SIGABRT` (exit 134) assim que toca no `CBCentralManager`, e o relatório de crash aponta o TCC, não o código. Foi o primeiro tropeço desta etapa.
