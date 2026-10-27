# Estratégia de testes — LogiBattery

Decisão de quais testes valem para cada parte do projeto. Catálogo de tipos e matriz default: `~/.claude/TESTES.md`. Partes definidas em [ARCHITECTURE.md](ARCHITECTURE.md). Estratégia aprovada pelo Lucas antes da implementação.

Status: rascunho

## 1. Formato da suíte
- Formato: Troféu
- Por quê: Uma aplicação só com regra, dados e telas: regra de negócio com unitários, integração (banco real de teste) como foco, E2E só nas jornadas críticas pela UI.

## 2. Testes por parte

Preencher uma linha por parte listada em ARCHITECTURE.md. Tipos: estático, unitário, componente, integração, API, contrato, E2E, aceitação, visual, desempenho, segurança, acessibilidade, migração.

| Parte | Risco principal | Tipos aplicados | Ferramenta | Roda em | Fora de escopo e motivo |
|---|---|---|---|---|---|
| Domínio (dedupe, regra de aviso, política de leitura) | Aviso repetido ou perdido, duplicata de aparelho | estático, unitário, aceitação | Swift Testing / XCTest | local, PR | Mutação só no núcleo crítico (custo) |
| HID++ (transporte e protocolo) | Frame mal interpretado, bateria errada, voltagem mal convertida | unitário (frames gravados), contrato do protocolo, smoke com hardware | Swift Testing com frames gravados e fake de `IOHIDDevice`; smoke manual com receptor e Bluetooth | local, PR (sem hardware) | Hardware real fora do CI; HID++ 1.0 fora do MVP |
| Persistência (snapshot e histórico) | Snapshot corrompido, histórico perdido, retenção errada | integração, migração | XCTest com App Group em diretório temporário; teste de migração de schema (quando houver) | PR | |
| Permissões do sistema (Input Monitoring, Bluetooth) | Leitura vazia sem explicação, entitlement faltando | unitário (estado), segurança | XCTest com fake de `IOHIDCheckAccess`; gitleaks + revisão de entitlements | PR | Fluxo real do painel de Privacidade só manual |
| Camada web / API / endpoints | - | - | N/A (app nativo, sem API de rede) | - | Contrato app e widget (snapshot JSON) coberto na linha de Persistência |
| Componentes de UI (popover, ajustes, widget) | Estado ou variante quebrada | componente, visual, acessibilidade | XCTest das ViewModels + SwiftUI previews; swift-snapshot-testing; Accessibility Inspector | local, PR | Visual do widget só em snapshot de view (WidgetKit não roda em teste) |
| Telas e fluxos | Jornada quebrada, divergência do protótipo aprovado | E2E, visual, acessibilidade | XCUITest (popover e ajustes); swift-snapshot-testing | PR (smoke), nightly | E2E só nas jornadas críticas; widget na galeria é manual |
| Integrações do sistema (notificações, login item) | Aviso não chega, login item não registra | integração com fake | XCTest com fake de `UNUserNotificationCenter` e `SMAppService` | PR | Entrega real de notificação e login real só manual |
| Jobs (polling e eventos HID++) | Leitura duplicada, polling parado, aparelho dormindo travando o ciclo | unitário, integração | XCTest com relógio e transporte falsos | PR | |
| Infra / build / distribuição | Build ou assinatura quebrada, app sem entitlement | estático, smoke | `xcodebuild build` no CI; `codesign --verify` e `spctl` na distribuição | PR, release | Notarização só quando houver distribuição |

"Roda em": local (pré-commit ou sob demanda), PR (CI bloqueante), deploy (smoke pós-deploy), nightly (agendado).

## 3. Testes do projeto inteiro
- Estático: SwiftLint + compilador com warnings como erro + gitleaks, no `lefthook.yml` e no CI.
- Smoke: `xcodebuild build` dos dois alvos (app e widget) e a suíte de unitários, primeiro job do CI. Smoke com hardware, manual, antes de cada release: receptor, Bluetooth e o mesmo aparelho pelos dois caminhos.
- Regressão: a suíte completa roda em todo PR. Bug corrigido entra com teste que falha antes da correção, no mesmo PR.
- Aceitação: cada história do `PRD.md` tem ao menos um teste (ou checagem manual descrita) ligado ao critério de aceite. Mapa em [Rastreabilidade](#5-rastreabilidade).
- Exploratório: antes de cada release, 30 min: dormir e acordar o Mac, desligar o aparelho, trocar de receptor, negar a permissão.
- Não funcionais: desempenho (XCTest measure + Instruments; meta: leitura completa abaixo de 2 s por aparelho), segurança (gitleaks + revisão de entitlements e Keychain), acessibilidade (XCUITest performAccessibilityAudit + Accessibility Inspector), compatibilidade (macOS 14 e o mais recente; Apple Silicon e Intel se houver máquina).

## 4. Regras
- Cada teste no nível mais baixo que pega o defeito; sem repetir caso de borda entre níveis.
- Teste de regra de negócio nasce antes ou junto do código (TDD, `/tdd`).
- Dependência externa nunca é real nos testes automatizados de PR: usar fake, stub ou servidor de teste. Produção nunca.
- Dados de teste: frames HID++ gravados em fixtures (`Tests/Fixtures/hidpp/`), sem série real; snapshots JSON de exemplo.
- Flaky: corrigir ou quarentenar com issue em até 1 semana; nunca reexecutar até passar.
- Cobertura: gate de 80% sobre Domínio e HID++. Cobertura é alarme, não meta.
- Teste visual/E2E de tela referencia o protótipo aprovado em `design/telas.md`.

## 5. Rastreabilidade

| História (PRD) | Critério de aceite | Teste(s) | Nível |
|---|---|---|---|
| US-01 | Aparelho por receptor aparece com nome e % | `HIDPPBatteryTests`, `ReceiverEnumerationTests`; smoke com receptor | unitário, manual |
| US-02 | Aparelho Bluetooth aparece com nome e % | `BluetoothDeviceTests`; smoke Bluetooth | unitário, manual |
| US-03 | Mesmo aparelho em dois caminhos vira um item | `DeviceDedupeTests` | unitário |
| US-04 | Estado carregando e cheio | `ChargeStateTests` | unitário |
| US-05 | Widget mostra nome, % e estado nos 3 tamanhos | `SnapshotContractTests`; snapshot visual por tamanho | integração, visual |
| US-06 | Popover lista aparelhos; ícone mostra o menor nível | `PopoverViewModelTests`; XCUITest do popover | componente, E2E |
| US-07 | Bateria baixa avisa uma vez e rearma | `LowBatteryRuleTests` | unitário |
| US-08 | Carga completa avisa uma vez por ciclo | `FullChargeRuleTests` | unitário |
| US-09 | Histórico em gráfico por período | `HistoryStoreTests`, `HistoryRetentionTests`; snapshot do gráfico | integração, visual |
| US-10 | Abrir no login | `LoginItemTests` (fake); manual | integração, manual |
| US-11 | Ajustes persistem e valem na próxima leitura | `SettingsStoreTests` | integração |
| US-12 | Guia de permissão e atalho ao painel | `PermissionStateTests`; manual | unitário, manual |

## 6. Comandos

```bash
xcodebuild test -scheme LogiBattery -destination 'platform=macOS'    # unitário + componente + integração
xcodebuild test -scheme LogiBatteryUITests -destination 'platform=macOS'     # E2E
swiftlint --strict    # estático
```

## 7. Pronto (Definition of Done) para PR
- [ ] Testes novos ou alterados cobrem a mudança no nível certo
- [ ] Suíte completa verde no CI
- [ ] Bug corrigido tem teste de regressão
- [ ] Tela nova ou alterada tem protótipo aprovado e teste (E2E/visual/a11y) conforme a tabela da seção 2
- [ ] Este arquivo atualizado se a estratégia mudou
