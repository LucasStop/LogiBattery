# Backlog — LogiBattery

Fonte das issues iniciais. `~/.claude/templates/criar-issues.sh` lê este arquivo e cria uma issue por bloco `## `. Depois de criadas, a issue no GitHub é a fonte; este arquivo vira histórico.

Formato do bloco: `## título`, linhas de metadado (`id:` nome curto, `labels: a, b`, `pai: id` vira sub-issue do pai, `depende: id1, id2` vira "bloqueada por"), corpo em Markdown. Id que não existe (bloco removido no perfil) é ignorado. Uma issue por história do [PRD](PRD.md) (título `US-01: ...`, critério de aceite copiado) mais as de fundação abaixo. Issue grande demais para um PR vira duas.

Status: aprovado. Aprovado em 2026-10-27

Issues criadas em 2026-10-29 (#2 a #24). #5 a #9 foram concluídas pelas aprovações de 2026-10-27 (PR #1).

## epic: Fundação
id: fundacao
labels: epic

Base do projeto antes de qualquer feature: esteira, estratégia de testes, arquitetura, design system, protótipos e contratos. Sub-issues abaixo.

## epic: MVP
id: mvp
labels: epic
depende: fundacao

Histórias do PRD. Cada sub-issue é uma história com critério de aceite.

## chore(ci): esteira de CI e lefthook rodando
id: ci
labels: fundacao
pai: fundacao

Rodar cada passo do CI localmente, `lefthook install`, ligar o CI no GitHub e marcar como obrigatório no ruleset. Ver `~/.claude/templates/esteira/README.md`.

Aceite: PR de teste passa no CI; commit com segredo é barrado pelo hook.

## docs(testing): estratégia de testes aprovada
id: testing
labels: fundacao
pai: fundacao

Revisar `docs/TESTING.md` (matriz do perfil), ajustar por risco e registrar `aprovada em AAAA-MM-DD`.

Aceite: `docs/TESTING.md` sem marcador de pendência e com aprovação datada.

## docs(architecture): arquitetura e partes aprovadas
id: architecture
labels: fundacao
pai: fundacao

Fechar `docs/ARCHITECTURE.md` (partes, fluxos, riscos) e registrar `aprovada em AAAA-MM-DD`.

Aceite: `docs/ARCHITECTURE.md` sem marcador de pendência e com aprovação datada.

## docs(design): design system aprovado
id: design
labels: fundacao, design
pai: fundacao
depende: architecture

Preencher `DESIGN.md` (tokens, tipografia, componentes, acessibilidade, microcopy) e registrar aprovação.

Aceite: `DESIGN.md` sem marcador de pendência e com aprovação datada.

## docs(design): prototipar e aprovar as telas
id: telas
labels: fundacao, design
pai: fundacao
depende: design

Um protótipo por tela do inventário em `design/telas.md`, usando os tokens do `DESIGN.md`. Tela só vira issue de implementação depois de aprovada.

Aceite: toda tela do MVP com protótipo e data de aprovação em `design/telas.md`.

## docs(api): contrato da API e modelo de dados aprovados
id: api
labels: fundacao
pai: fundacao
depende: architecture

Preencher `docs/API.md` e `docs/DATA.md` e registrar aprovação.

Aceite: os dois docs sem marcador de pendência e com aprovação datada.

## spike(hidpp): descobrir hardware e validar leitura de bateria
id: spike-hidpp
labels: fundacao, spike
pai: fundacao
depende: architecture

Descobrir modelos e PID do receptor do Lucas (`ioreg -p IOUSB -l`), enumerar com `IOHIDManager` (vendor `0x046D`) e ler bateria por HID++ 2.0 em um aparelho por receptor e um por Bluetooth. Gravar frames reais (sem série) como fixtures.

Aceite: frames gravados em `Tests/Fixtures/hidpp/` e nota em `docs/ARCHITECTURE.md` com features achadas por aparelho.

## chore(project): esqueleto XcodeGen com app, widget e testes
id: skeleton
labels: fundacao
pai: fundacao
depende: ci, architecture

`project.yml` com alvos `LogiBattery`, `LogiBatteryWidget`, `LogiBatteryTests`, `LogiBatteryUITests`, App Group e entitlements (USB, Bluetooth), bundle id definitivo, `Localizable.xcstrings` (pt-BR e en). Ligar o CI de build e teste.

Aceite: `xcodegen generate && xcodebuild test -scheme LogiBattery` passa no CI e local.

## US-01: Bateria de aparelhos por receptor
id: us-01
labels: feature
pai: mvp
depende: skeleton, spike-hidpp, ci, testing, architecture, api

Como usuário, quero ver a bateria dos meus mouse e teclado Logitech ligados por receptor, para saber quando recarregar.

Aceite: Dado um receptor Unifying, Bolt ou Lightspeed com aparelho pareado e ligado, quando o app lê o dispositivo, então aparecem nome do aparelho e porcentagem de bateria.

## US-02: Bateria de aparelhos Bluetooth
id: us-02
labels: feature
pai: mvp
depende: us-01

Como usuário, quero ver também os aparelhos Bluetooth, para ter tudo na mesma lista.

Aceite: Dado um aparelho Logitech conectado por Bluetooth, quando o app lê o dispositivo, então ele aparece com nome e porcentagem.

## US-03: Deduplicar aparelho em dois caminhos
id: us-03
labels: feature
pai: mvp
depende: us-01, us-02

Como usuário, quero que o mesmo aparelho visto por receptor e por Bluetooth apareça uma vez, para não ter duplicata.

Aceite: Dado um aparelho pareado por receptor e por Bluetooth, quando ambos os caminhos respondem, então a lista mostra um único item, com a leitura do caminho ativo.

## US-04: Estado de carga
id: us-04
labels: feature
pai: mvp
depende: us-01

Como usuário, quero saber se o aparelho está carregando ou com carga completa, para não deixá-lo na tomada sem necessidade.

Aceite: Dado um aparelho que reporta estado de carga, quando ele está no carregador, então o estado aparece como carregando ou cheio.

## US-05: Widget com as baterias
id: us-05
labels: feature
pai: mvp
depende: us-01, telas

Como usuário, quero um widget com as baterias, para ver de relance na Mesa ou Central de Notificações.

Aceite: Dado ao menos um aparelho lido, quando o widget é exibido, então mostra nome, porcentagem e estado de cada aparelho nos tamanhos pequeno, médio e grande.

## US-06: Ícone e popover na barra de menu
id: us-06
labels: feature
pai: mvp
depende: us-01, telas

Como usuário, quero um ícone na barra de menu com popover, para consultar sem abrir janela.

Aceite: Dado o app rodando, quando clico no ícone, então o popover lista os aparelhos, e o ícone indica o menor nível de bateria.

## US-07: Aviso de bateria baixa
id: us-07
labels: feature
pai: mvp
depende: us-01, us-04

Como usuário, quero aviso de bateria baixa, para recarregar antes de acabar.

Aceite: Dado um limite configurado (padrão 20% e 10%), quando a bateria de um aparelho cai abaixo dele sem estar carregando, então chega uma notificação uma única vez até ele recarregar acima do limite.

## US-08: Aviso de carga completa
id: us-08
labels: feature
pai: mvp
depende: us-04, us-07

Como usuário, quero aviso de carga completa, para tirar o aparelho da tomada.

Aceite: Dado um aparelho carregando, quando ele atinge o estado cheio, então chega uma notificação uma única vez por ciclo de carga.

## US-09: Histórico em gráfico
id: us-09
labels: feature
pai: mvp
depende: us-01, telas

Como usuário, quero o histórico da bateria em gráfico, para entender a duração e o padrão de uso.

Aceite: Dado leituras guardadas, quando abro o gráfico de um aparelho, então vejo a porcentagem ao longo do tempo (24 h, 7 dias, 30 dias).

## US-10: Abrir no login
id: us-10
labels: feature
pai: mvp
depende: us-11

Como usuário, quero que o app abra no login, para não precisar iniciar à mão.

Aceite: Dado a opção ligada nos ajustes, quando faço login no Mac, então o app inicia sozinho na barra de menu.

## US-11: Ajustes
id: us-11
labels: feature
pai: mvp
depende: telas, testing

Como usuário, quero ajustar limites e opções, para adequar os avisos à minha rotina.

Aceite: Dado a tela de ajustes, quando altero limites, intervalo de leitura ou opções de aviso, então a mudança vale na próxima leitura e persiste após reiniciar.

## US-12: Guia de permissão
id: us-12
labels: feature
pai: mvp
depende: telas, ci

Como usuário, quero ser guiado quando falta permissão, para destravar a leitura sem adivinhar.

Aceite: Dado que o macOS negou Input Monitoring, quando abro o app, então vejo a explicação e um botão que leva ao painel de Privacidade correto.

## chore(release): distribuição com Developer ID e notarização
id: distribuicao
labels: infra
pai: mvp
depende: us-12

Assinar com Developer ID, notarizar, validar Input Monitoring e sandbox fora da assinatura local, empacotar (dmg ou zip) e documentar a instalação. Não bloqueia o MVP de uso próprio.

Aceite: `codesign --verify` e `spctl --assess` passam; instalação em Mac limpo lê os aparelhos.
