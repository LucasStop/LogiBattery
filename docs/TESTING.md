# Estratégia de testes — LogiBattery

Decisão de quais testes valem para cada parte do projeto. Catálogo de tipos e matriz default: `~/.claude/TESTES.md`. Partes definidas em [ARCHITECTURE.md](ARCHITECTURE.md). Estratégia aprovada pelo Lucas antes da implementação.

Status: aprovada em 2026-10-27

## 1. Formato da suíte
- Formato: Troféu
- Por quê: Uma aplicação só com regra, dados e telas: regra de negócio com unitários, integração (banco real de teste) como foco, E2E só nas jornadas críticas pela UI.

## 2. Testes por parte

Preencher uma linha por parte listada em ARCHITECTURE.md. Tipos: estático, unitário, componente, integração, API, contrato, E2E, aceitação, visual, desempenho, segurança, acessibilidade, migração.

| Parte | Risco principal | Tipos aplicados | Ferramenta | Roda em | Fora de escopo e motivo |
|---|---|---|---|---|---|
| Domínio (dedupe, regra de aviso, política de leitura) | Aviso repetido ou perdido, duplicata de aparelho | estático, unitário, aceitação | Swift Testing / XCTest | local, PR | Mutação só no núcleo crítico (custo) |
| HID++ (transporte e protocolo) | Frame mal interpretado, bateria errada, voltagem mal convertida | unitário (frames gravados), contrato do protocolo, smoke com hardware | Swift Testing com frames gravados e fake de `IOHIDDevice`; smoke manual com receptor e Bluetooth | local, PR (sem hardware) | Hardware real fora do CI; HID++ 1.0 fora do MVP |
| Bateria do sistema (Mac e fone Bluetooth) | % errado, estado de carga trocado, fone desligado que não some | unitário (dicionário do `IOPowerSources` gravado, níveis do fone) | XCTest (`SystemBatteriesTests`, `KeepLastReadingTests`) | local, PR | Leitura real do `IOPowerSources` e do `IOBluetooth` só no smoke manual: depende do hardware e da permissão de Bluetooth |
| Persistência (snapshot e histórico) | Snapshot corrompido, histórico perdido, retenção errada | integração, migração | XCTest com App Group em diretório temporário; teste de migração de schema (quando houver) | PR | |
| Permissões do sistema (Input Monitoring, Bluetooth) | Leitura vazia sem explicação, entitlement faltando | unitário (estado), segurança | XCTest com fake de `IOHIDCheckAccess`; gitleaks + revisão de entitlements | PR | Fluxo real do painel de Privacidade só manual |
| Camada web / API / endpoints | - | - | N/A (app nativo, sem API de rede) | - | Contrato app e widget (snapshot JSON) coberto na linha de Persistência |
| Componentes de UI (popover, ajustes, widget) | Estado ou variante quebrada | componente, visual, acessibilidade | XCTest das ViewModels e do contrato do snapshot; SwiftUI previews; Accessibility Inspector manual | local, PR | Snapshot visual (swift-snapshot-testing) fora por ora: dependência nova para poucas telas; visual conferido por print contra o protótipo |
| Telas e fluxos | Jornada quebrada, divergência do protótipo aprovado | E2E, visual, acessibilidade | XCUITest só de lançamento (`LaunchUITests`); jornadas manuais | local | Popover de `MenuBarExtra` não abre por XCUITest de forma confiável; popover, ajustes e widget na galeria são conferidos à mão |
| Integrações do sistema (notificações, login item) | Aviso não chega, login item não registra | integração com fake | XCTest com fake de `UNUserNotificationCenter` e `SMAppService` | PR | Entrega real de notificação e login real só manual |
| Jobs (polling e eventos HID++) | Leitura duplicada, polling parado, aparelho dormindo travando o ciclo, regra de ciclo de vida (aparece, cinza, some) divergindo entre popover e widget | unitário, integração, cenário | XCTest com relógio injetado (`DeviceListViewModel(now:)`) e scanner roteirizado: `DeviceLifecycleScenarioTests` conta cada história com o tempo andando (30 min, 24 h, relaunch, intervalo de 45 min) | PR | |
| Site público (`site/`, landing estática, #92 e #106) | Contraste, foco, alvo de toque ou `alt` quebrados; texto fixo fora do dicionário; scroll horizontal no mobile; token literal fora do `:root` | estático, acessibilidade, visual | Lighthouse (acessibilidade >= 95, boas práticas e SEO) em mobile e desktop, via `chrome-devtools`; Playwright para claro/escuro, pt-BR/en/es e 360 px; contraste calculado (WCAG) conforme DESIGN.md §9.2 | local, a cada PR que mexe em `site/` | Teste unitário de JS (só troca de idioma e copiar chave, sem regra de negócio); CI do site não existe ainda (deploy por GitHub Pages) |
| Infra / build / distribuição | Build ou assinatura quebrada, app sem entitlement | estático, smoke | `xcodebuild build` no CI; `codesign --verify` e `spctl` na distribuição | PR, release | Notarização só quando houver distribuição |

"Roda em": local (pré-commit ou sob demanda), PR (CI bloqueante), deploy (smoke pós-deploy), nightly (agendado).

## 3. Testes do projeto inteiro
- Estático: SwiftLint `--strict` + gitleaks no `lefthook.yml` (pre-commit, só o staged) e no CI (#117: `gitleaks git` no histórico inteiro, antes do build e bloqueante; roda o binário do brew, sem action de terceiro nem segredo novo). Warnings do compilador não viram erro (fora por ora: o Xcode gera avisos do sistema que não são nossos).
- Smoke: `xcodebuild build` dos dois alvos (app e widget) e a suíte de unitários, primeiro job do CI. Smoke com hardware, manual, antes de cada release: receptor, Bluetooth e o mesmo aparelho pelos dois caminhos, incluindo trocar o mouse do receptor para o Bluetooth com o app aberto (ele deve aparecer como Bluetooth em até ~15 s, sem reiniciar o app). Receptor: `LOGIBATTERY_HW=1 TEST_RUNNER_LOGIBATTERY_HW=1 xcodebuild test -scheme LogiBattery -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` roda `HardwareSmokeTests` (pulado sem a variável).
- Regressão: a suíte completa roda em todo PR e o job compara com a última run verde da `main` (relatório abaixo). Bug corrigido entra com teste que falha antes da correção, no mesmo PR.
- Relatório de testes no CI (#117): verde ou vermelho não diz o que mudou, então o job gera um resumo por run.
  - Como nasce: `xcodebuild test` grava `build/tests.xcresult`; `scripts/test-report.sh` (xcresulttool + jq) gera `build/test-report.json` (total, passou, falhou, pulou, duração, id e status de cada teste, média das métricas do `measure`) e escreve o Markdown no resumo do job. O passo roda com teste vermelho também.
  - Comparação: push na `main` publica o JSON como artifact `test-report` (90 dias). No PR, o job baixa o da última run verde da `main` (`gh run download`, sem action de terceiro) e compara. Sem artifact (primeira run, expirado), mostra só o relatório atual, sem erro.
  - Como ler a **Regressão**: o que piorou contra a `main`. Teste da `main` que agora falha, que sumiu ou que passou a ser pulado, e orçamento de desempenho estourado (suíte `*PerformanceTests`). Pede ação antes do merge; teste que sumiu só é aceitável se o PR o removeu de propósito, e a descrição do PR diz por quê.
  - Como ler a **Evolução**: só informativa. Testes novos por nome, total (±N) e duração (±s). A duração varia com o runner, vale como tendência e nunca como limite.
  - Local: `xcodebuild test ... -resultBundlePath build/tests.xcresult` e `scripts/test-report.sh build/tests.xcresult [test-report.json da main]` imprime o mesmo Markdown no terminal.
- Aceitação: cada história do `PRD.md` tem ao menos um teste (ou checagem manual descrita) ligado ao critério de aceite. Mapa em [Rastreabilidade](#5-rastreabilidade).
- Visual do widget (#64), manual, em todo PR que mexe no widget: pequeno e médio ao lado do Baterias da Apple em cada estilo de Ajustes > Aparência > Estilo dos ícones e widgets, e com Mesa e Dock > Atenuar widgets na mesa. Para ver a mudança: reinstalar, `pkill -x LogiBatteryWidget; killall chronod` e esperar uns 40 s. Prints em `design/screenshots/t01-t02-widget-*.png` (macOS 27, 2026-11-03; na ordem: médio da Apple, nosso médio, nosso pequeno, pequeno da Apple).

  | Estilo | Modo | Esperado | Print |
  |---|---|---|---|
  | Tom escuro (sistema escuro) | `.fullColor` | base cinza-escura do sistema, anéis na cor do nível | `tom-escuro` |
  | Padrão (sistema escuro) | `.fullColor` | igual ao tom escuro | `padrao` |
  | Padrão (sistema claro) | `.fullColor` | base branca, ícone e texto escuros | `padrao-sistema-claro` |
  | Translúcido | `.accented` | vidro do sistema, anel na cor do nível, ícone e texto brancos | `translucido` |
  | Tonalizado | `.accented` | vidro tingido, anel na cor do nível, ícone e texto na cor do tom | `tonalizado` |
  | Atenuar widgets: sempre | `.vibrant` | ícone e texto dessaturados, anel na cor do nível mais apagada, legível | `atenuado` |

  Limite conhecido: no padrão e no tom escuro o Baterias da Apple mostra o papel de parede atrás e o nosso não. A base translúcida é do sistema, só para widget da Apple; widget de terceiro (o nosso e o Stats) recebe a base opaca (spike da #64 em DESIGN.md §3.7).
- Release ([ADR 0004](adr/0004-versionamento-semver-e-release-por-script.md)): `scripts/next-version.sh` testado com repo git de fixture (feat sobe MINOR, fix sobe PATCH, sem commit relevante não sobe); o CI falha se a tag divergir do `MARKETING_VERSION`.
- Exploratório: antes de cada release, 30 min: dormir e acordar o Mac, desligar o aparelho, trocar de receptor, negar a permissão.
- Não funcionais: desempenho (`ScanPerformanceTests`: orçamento em contagem de trocas HID++ e timeouts por scan, com aparelho dormindo, e paralelismo entre endpoints; `measure` do dedupe só para tendência local; Instruments sob demanda; meta: leitura completa abaixo de 2 s por aparelho), segurança (gitleaks + revisão de entitlements e Keychain), acessibilidade (Accessibility Inspector manual; `performAccessibilityAudit` fora junto com o E2E do popover), compatibilidade (macOS 14 e o mais recente; Apple Silicon e Intel se houver máquina).

## 4. Regras
- Cada teste no nível mais baixo que pega o defeito; sem repetir caso de borda entre níveis.
- Teste de regra de negócio nasce antes ou junto do código (TDD, `/tdd`).
- Dependência externa nunca é real nos testes automatizados de PR: usar fake, stub ou servidor de teste. Produção nunca.
- Dados de teste: frames HID++ gravados em fixtures (`Tests/Fixtures/hidpp/`), sem série real; snapshots JSON de exemplo.
- Flaky: corrigir ou quarentenar com issue em até 1 semana; nunca reexecutar até passar.
- Cobertura: sem gate no CI e sem número no relatório (fora por escolha do Lucas: suíte pequena, revisão pega o buraco). Se entrar, 80% sobre Domínio e HID++, como alarme e não meta.
- Desempenho: o baseline é contagem determinística (trocas, timeouts, aparelhos em voo), nunca segundos. O `measure` do XCTest guarda o baseline por máquina e o runner do GitHub muda a cada job, então ele serve só para tendência local e não tem baseline commitado. Orçamento estourado é teste vermelho e aparece na Regressão do relatório.
- Teste visual/E2E de tela referencia o protótipo aprovado em `design/telas.md`.

## 5. Rastreabilidade

| História (PRD) | Critério de aceite | Teste(s) | Nível |
|---|---|---|---|
| US-01 | Aparelho por receptor aparece com nome e %; dormindo fica, vai para o fim, fica cinza e some nos tempos dos Ajustes (padrão 30 min e 24 h) | `HIDPPBatteryTests` (inclui erro `0xFF`, software id e frame curto, #116), `ReceiverEnumerationTests`, `KeepLastReadingTests`, `DeviceLifecycleScenarioTests` (histórias com relógio falso), `DeviceEventFilterTests`; política dos Ajustes (#115): `testApplyingANewPolicyReachesTheListAndThePublishedSnapshotAtOnce`, `testForgetScopeDecidesWhetherAKeptReadingThatIsStillGreenCanBeForgotten`, `testReadingTurningGrayUnderTheNewPolicyReloads`; smoke com receptor | unitário, cenário, manual |
| US-02 | Aparelho Bluetooth aparece com nome e % | `BluetoothDeviceTests`; smoke Bluetooth | unitário, manual |
| US-03 | Mesmo aparelho em dois caminhos vira um item | `DeviceDedupeTests` | unitário |
| US-04 | Estado carregando e cheio | `ChargeStateTests` | unitário |
| US-05 | Widget mostra os aparelhos e o estado nos 3 tamanhos (anéis 2x2 sem % no pequeno, 4x1 com % no médio, lista no grande; paginação no médio a partir do 5º e no grande a partir do 7º) | `SnapshotContractTests`, `WidgetReloadTests` (reload só com mudança, leitura velha), `WidgetPaginationTests` (#79), `DeviceSymbolTests` (#65 e #75); print por tamanho comparado aos protótipos T01 a T03 e T09, com 1 a 4 aparelhos (posição vazia) | unitário, integração, manual |
| US-06 | Popover lista aparelhos; ícone mostra o menor nível | `PopoverViewModelTests`; manual | componente, manual |
| US-07 | Bateria baixa avisa uma vez e rearma | `LowBatteryRuleTests` | unitário |
| US-08 | Carga completa avisa uma vez por ciclo | `FullChargeRuleTests` | unitário |
| US-09 | Histórico em gráfico por período | `HistoryStoreTests`, `HistoryRetentionTests`, `HistorySeriesTests`; print do gráfico | integração, manual |
| US-10 | Abrir no login | `LoginItemTests` (fake); manual | integração, manual |
| US-11 | Ajustes persistem e valem na próxima leitura; cores seguem os limites no app e no widget | `SettingsTests` (inclui `grayAfterMinutes`, `keepForMinutes`, `forgetScope` e `onChange`), `SnapshotContractTests` (limites e `policy` no snapshot, snapshot antigo sem `policy`) | integração |
| US-12 | Guia de permissão e atalho ao painel | `PermissionModelTests`; manual | unitário, manual |
| US-13 | Mac e fone Bluetooth aparecem; fone desligado some | `SystemBatteriesTests` (inclui o processo filho fora da main, #116), `KeepLastReadingTests` (fone não é mantido), `DeviceLifecycleScenarioTests` (Bluetooth e fone somem na hora, fone sem nível mantém a última), `SnapshotContractTests` (Mac primeiro, tipos novos); smoke: `snapshot.json` com Mac e fone | unitário, cenário, manual |
| US-15 | Teclado e mouse BLE de qualquer marca aparecem pelo Battery Service; HID++ não duplica | `SystemBatteriesTests` (`testBLEBatteryServiceReadingBecomesAKeyboardOfAnyBrand`, nível fora de 1...100, `testHIDPPReadingWinsOverTheGenericBLEReadingOfTheSameDevice`); smoke: `snapshot.json` com o KF8700 | unitário, manual |
| US-14 | Ícone escondido some, leitura segue e o ícone volta ao reabrir o app | manual: desligar o toggle (o `generatedAt` do `snapshot.json` continua avançando), `open ~/Applications/LogiBattery.app` traz o ícone de volta, clique no widget idem, logout e login com o ícone escondido | manual |

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
