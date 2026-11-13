# HID++ — o que os aparelhos do projeto expõem

Referência do protocolo medido nos aparelhos do Lucas. Complementa [ARCHITECTURE.md](ARCHITECTURE.md) §11 e as fixtures de `Tests/Fixtures/hidpp/`.

Status: medido em 2026-11-12 (macOS, macOS 26). Somente leitura; nenhuma escrita de configuração foi feita nos aparelhos.

## 1. Como a tabela é lida

Todo aparelho HID++ 2.0 responde à feature `0x0001` (FeatureSet) com a lista do que o firmware implementa:

1. Root `0x0000` função 0 com `[id hi, id lo]` devolve o **slot** da feature `0x0001`.
2. Nesse slot, função 0 devolve a **quantidade** de entradas.
3. Função 1 com o número da entrada devolve `[id hi, id lo, tipo|versão]`.

O byte 3 da resposta empacota **versão no nibble alto** e **tipo no baixo** (mesma leitura de `hidpp20.py` do Solaar). O slot é o que vai no byte 2 dos frames seguintes; por isso o app guarda slot, não só o ID.

Implementação: `HIDPPFeatureTable` em [`LogiBattery/Core/HIDPP/HIDPPFeatures.swift`](../LogiBattery/Core/HIDPP/HIDPPFeatures.swift), lida por `HIDPPSession.featureTable()`.

## 2. Como reproduzir

```bash
swiftc -O tools/hidpp-dump/main.swift LogiBattery/Core/HIDPP/HIDPPFeatures.swift -o /tmp/hidpp-dump
/tmp/hidpp-dump
# gravar frames como fixture:
HIDPP_RECORD=Tests/Fixtures/hidpp/features-<nome>.txt /tmp/hidpp-dump
```

O tool abre a interface vendor `usagePage 0xFF00`/usage `0x01` de cada receptor, testa os índices 1 a 6 e imprime nome, protocolo e tabela. Ele compartilha o catálogo de nomes com o app, então nome errado corrige nos dois lugares de uma vez.

Achado operacional: com o aparelho dormindo, o Bolt chega a responder depois de ~0,6 s. O dump espera 1,6 s no primeiro frame e para cedo quando o receptor responde HID++ 1.0 `10 idx 8F` (slot sem aparelho). O app usa 1 s por troca; leitura de aparelho dormindo é tratada pela política de leitura, não por timeout maior.

## 3. PRO X TKL (Lightspeed `0xC547`, índice 1, HID++ 4.2)

33 features. As que importam para o produto:

| Slot | ID | Feature | Versão | O que habilita |
|---|---|---|---|---|
| 7 | `0x1004` | UnifiedBattery | 0 | Bateria (já lida pelo app) |
| 8 | `0x8071` | RgbEffects | 0 | Efeito/cor do RGB sem G HUB |
| 9 | `0x8081` | PerKeyLightingV2 | 0 | Cor por tecla (escrita zona a zona) |
| 16 | `0x8040` | BrightnessControl | 0 | Brilho do RGB |
| 18 | `0x8060` | ReportRate | 0 | Taxa de polling (1.000/500/125 Hz) |
| 17 | `0x8100` | OnboardProfiles | 0 | Perfis gravados no teclado |
| 11 | `0x40A3` | K375sFnInversion | 0 | Fn lock no firmware |
| 15 | `0x8010` | GKey | 0 | Teclas G / camadas |
| 10 | `0x1BC0` | ReportHIDUsage | 0 | Uso HID reportado |
| 29 | `0x1E00` | EnableHiddenFeatures | 4 | Libera features escondidas |
| 4 | `0x1D4B` | WirelessDeviceStatus | 0 | Estado do link |
| 19 | `0x00D0` | DFU | 0 | Atualização de firmware (não usar) |

Tabela completa, na ordem do firmware:

```
 1 0x0001 FeatureSet              12 0x1B10 (?)                  23 0x1817 (?)                  
 2 0x0003 DeviceFWVersion         13 0x4523 (?)                  24 0x1805 OOBState             
 3 0x0005 DeviceName              14 0x4540 KeyboardLayout2       25 0x1830 (?)                  
 4 0x1D4B WirelessDeviceStatus    15 0x8010 GKey                  26 0x1890 (?) t8               
 5 0x0020 Reset                   16 0x8040 BrightnessControl    27 0x1891 (?) t8               
 6 0x0007 DeviceFriendlyName      17 0x8100 OnboardProfiles      28 0x18A1 (?)                  
 7 0x1004 UnifiedBattery          18 0x8060 ReportRate           29 0x1E00 EnableHiddenFeatures 
 8 0x8071 RgbEffects              19 0x00D0 DFU                  30 0x1EB0 (?)                  
 9 0x8081 PerKeyLightingV2        20 0x1802 DeviceReset v7       31 0x1861 (?)                  
10 0x1BC0 ReportHIDUsage          21 0x1803 (?) v7               32 0x18B0 (?)                  
11 0x40A3 K375sFnInversion        22 0x1806 ConfigDeviceProps v7  33 0x1801 (?)                  
```

O que **não** existe: `0x8070` (ColorLedEffects), `0x8061` (report rate estendido, acima de 1 kHz) e `0x1982` (Backlight2). O RGB deste teclado é o trio `0x8071` + `0x8081` + `0x8040`, não o `0x8070` das linhas MX. Não há feature de bateria legada (`0x1000`/`0x1001`): só `0x1004`.

## 4. MX Master 3S (Bolt `0xC548`, índice 2, HID++ 4.5)

35 features. As que importam:

| Slot | ID | Feature | Versão | O que habilita |
|---|---|---|---|---|
| 8 | `0x1004` | UnifiedBattery | 0 | Bateria (já lida pelo app) |
| 13 | `0x2201` | AdjustableDpi | 0 | DPI (faixa e presets) |
| 14 | `0x2110` | SmartShift | 0 | Modo da roda e força de troca |
| 15 | `0x2121` | HiResWheel | 0 | Scroll de alta resolução e inversão |
| 16 | `0x2150` | ThumbWheel | 0 | Roda lateral |
| 9 | `0x1B04` | ReprogControlsV4 | 0 | Remap e divert de botões |
| 10 | `0x1814` | ChangeHost | 0 | Trocar canal Bolt/BT |
| 11 | `0x1815` | HostsInfo | 0 | Ler canal ativo e nomes |
| 12 | `0x2250` | XYStats | 0 | Distância percorrida (diagnóstico) |
| 17 | `0x2251` | WheelStats | 0 | Voltas de roda (diagnóstico) |
| 6 | `0x0021` | CryptoID | 0 | Identidade criptográfica do link |
| 27 | `0x1E00` | EnableHiddenFeatures | 4 | Libera features escondidas |

Tabela completa:

```
 1 0x0001 FeatureSet              13 0x2201 AdjustableDpi          25 0x1891 (?) t8              
 2 0x0003 DeviceFWVersion         14 0x2110 SmartShift             26 0x18A1 (?)                 
 3 0x0005 DeviceName              15 0x2121 HiResWheel             27 0x1E00 EnableHiddenFeatures
 4 0x1D4B WirelessDeviceStatus    16 0x2150 ThumbWheel             28 0x1E02 (?)                 
 5 0x0020 Reset                   17 0x2251 WheelStats             29 0x1602 (?)                 
 6 0x0021 CryptoID                18 0x00C3 (?)                   30 0x1EB0 (?)                 
 7 0x0007 DeviceFriendlyName      19 0x1802 DeviceReset v7        31 0x1861 (?)                 
 8 0x1004 UnifiedBattery          20 0x1803 (?) v7                32 0x9300 (?)                 
 9 0x1B04 ReprogControlsV4        21 0x1806 ConfigDeviceProps v7   33 0x9001 (?)                 
10 0x1814 ChangeHost              22 0x1816 (?) v7                34 0x1E22 (?)                 
11 0x1815 HostsInfo               23 0x1805 OOBState v6            35 0x9205 (?)                 
12 0x2250 XYStats                 24 0x1830 (?) v7                                              
```

O que **não** existe: `0x2202` (DPI estendido, X/Y e lift-off), `0x2111` (SmartShift aprimorado), `0x2205` (PointerSpeed), `0x40A*` (teclado) e `0x8060` (ReportRate, exclusivo da linha G).

## 5. Feature desconhecida não ganha nome

`HIDPPFeatureCatalog` só nomeia o que tem evidência na tabela do Solaar ou nos documentos do projeto. Os IDs abaixo aparecem nos aparelhos e ficam como hex, de propósito:

`0x1B10`, `0x4523`, `0x00C3`, `0x1602`, `0x1801`, `0x1803`, `0x1816`, `0x1817`, `0x1830`, `0x1861`, `0x1890`, `0x1891`, `0x18A1`, `0x18B0`, `0x1E02`, `0x1E22`, `0x1EB0`, `0x9001`, `0x9205`, `0x9300`.

Nome inventado sugere capacidade que o firmware pode não ter. Para nomear, a via é dump antes/depois de ligar `0x1E00` e comparar a tabela, ou observar o tráfego do G HUB/Options+ numa máquina de teste.

## 6. O que isso destrava (e o que não destrava)

Rentável e de baixo risco:
- Bateria por componente: o teclado G hoje só tem `0x1004`; nada de leitura extra necessária.
- RGB e brilho do teclado sem G HUB, que não está instalado nesta máquina.
- Perfil onboard (`0x8100`): configuração sobrevive a trocar de máquina e a desinstalar app.
- Report rate (`0x8060`) do teclado: já é 1 kHz de fábrica; serve para baixar e economizar bateria, não para subir.
- Mouse: DPI, SmartShift, HiResWheel e remap no firmware.
- Diagnóstico: `0x2250`/`0x2251` dão distância e uso da roda sem telemetria externa.

Não destrava:
- Polling acima de 1 kHz: `0x8061` não existe no teclado.
- DPI acima de 8.000 no 3S: é limite físico do sensor.
- Mais desempenho por firmware: o link Lightspeed/Bolt é criptografado e o firmware não é acessível por HID++.

## 7. Riscos antes de escrever

- O Logi Options+ mantém o Bolt aberto. Leitura convive; escrita precisa de dono único, senão o agente reaplica o perfil dele.
- `0x1E00` muda a tabela de features. Se for usado, o dump tem que ser refeito e a diferença registrada aqui.
- Escrita de RGB/perfil não tem rollback automático: `set` só entra com leitura de confirmação e `--dry-run` no CLI.
- Firmware (`0x00D0` DFU) não entra em nenhuma fase. É o único caminho com risco real de tijolar.
