# LogiBattery — DESIGN.md

Design system do projeto. É a fonte única de identidade visual e de padrões de interface: o `/frontend-design` e o `/impeccable` leem este arquivo antes de gerar UI. Regras globais em `~/.claude/CLAUDE.md` valem; aqui só o que é deste repo.

Regra de fluxo: nenhuma tela é implementada antes de ter protótipo aprovado pelo Lucas (ver [Fluxo de protótipo e aprovação](#fluxo-de-protótipo-e-aprovação) e [design/telas.md](design/telas.md)). Mudança em token ou componente atualiza este arquivo no mesmo PR.

Status do design system: aprovada em 2026-10-27

Formato: o dos DESIGN.md de marca do [VoltAgent/awesome-design-md](https://github.com/voltagent/awesome-design-md) (visão geral, cor, tipografia, layout, materiais e profundidade, forma, componentes, faça e não faça). Referência de visual: a Apple nativa, com o HIG e o widget Baterias do macOS medido em print como fonte de verdade (#57).

## 1. Visão geral e marca
- Produto: monitor de bateria de periféricos Logitech para macOS, em widget e barra de menu.
- Público: pessoa que trabalha no Mac o dia todo com mouse e teclado sem fio; consulta de relance, várias vezes ao dia.
- Personalidade: discreto, nativo, preciso, calmo.
- Conceito visual: um indicador de nível (o anel no widget, a célula no popover) como forma central; o número é o protagonista, a cor só sinaliza urgência.
- Objetivo: lado a lado com o widget Baterias da Apple, o nosso não parece de terceiro.
- Características-chave:
  - anel de ponta redonda nos widgets pequeno e médio, com as medidas do Baterias (§3.8);
  - ícone do aparelho grande e em cor primária no centro do anel;
  - selo de conexão desenhado dentro do ícone, num SF Symbol próprio (§3.6);
  - fundo e materiais do sistema: o widget ganha vidro quando o macOS aplica o Liquid Glass, nunca vidro próprio (§3.7);
  - cor própria só no anel e no número, e só para o nível; o resto é cor semântica do sistema.
- Referências que gosto: widget Baterias e Ajustes do macOS (nativo, legível, sem enfeite); Logi Options+ só como referência de informação, não de visual.
- Anti-referências: painel de gamer com RGB, gauge decorativo, tema que briga com o macOS.
- Logo / ícone: ícone do app na seção [Ícone do app](#ícone-do-app) (opção A, `design/icon/appicon.svg`); na barra de menu, SF Symbol `battery.*` monocromático com o menor percentual ao lado.

## 2. Princípios de design
- O número vem primeiro: porcentagem legível a 1 metro de distância, antes de qualquer decoração.
- Parecer parte do macOS: componentes, ícones (SF Symbols) e tipografia do sistema.
- Cor sinaliza estado, nunca é o único sinal: baixo e crítico também mudam ícone e texto.
- Aparelho sem leitura mostra a última conhecida com a hora, nunca um zero falso.

## 3. Tokens

Os tokens próprios (cores de nível) vivem em código em `LogiBattery/UI/Components/BatteryCell.swift` (`BatteryLevel.color`, `Device.tint`, com variante clara e escura); o resto são cores semânticas do sistema. Este arquivo documenta; o código é a implementação. Componente nunca usa valor literal, só token.

### 3.1 Cor
Base: cores semânticas do sistema (`NSColor`/`Color`) para acompanhar o tema e o acento do usuário. Só os tokens de nível de bateria são próprios.

| Token semântico | Claro | Escuro | Uso |
|---|---|---|---|
| `background` | `windowBackgroundColor` | `windowBackgroundColor` | Fundo de janela e popover |
| `surface` | `controlBackgroundColor` | `controlBackgroundColor` | Cartões de aparelho |
| `surface-raised` | `underPageBackgroundColor` | `underPageBackgroundColor` | Elementos elevados |
| `foreground` | `labelColor` | `labelColor` | Texto principal |
| `muted` | `secondaryLabelColor` | `secondaryLabelColor` | Texto secundário, hora da leitura |
| `border` | `separatorColor` | `separatorColor` | Divisórias |
| `primary` | `controlAccentColor` | `controlAccentColor` | Ação principal e foco |
| `primary-hover` | acento a 85% | acento a 85% | Hover e pressionado |
| `primary-foreground` | `white` | `white` | Texto sobre o primário |
| `success` (nível ok e cheio) | #1F9D55 | #34C77B | Bateria acima do limite, carga cheia |
| `warning` (nível baixo) | #B7791F | #F2B13C | Bateria abaixo do limite baixo dos Ajustes (padrão 20%) |
| `danger` (nível crítico) | #C53030 | #FF6B6B | Bateria abaixo do limite crítico dos Ajustes (padrão 10%), no app e no widget |
| `info` (carregando) | #2B6CB0 | #63B3ED | Aparelho no carregador |
| `focus-ring` | `keyboardFocusIndicatorColor` | idem | Foco de teclado |
| `disabled` | `disabledControlTextColor` | idem | Controle desabilitado, aparelho sem leitura |

- Dark mode: sim; segue o sistema, mesma hierarquia nos dois modos.
- Contraste: texto >= 4,5:1 (3:1 para texto grande e ícones de UI) contra o fundo, nos dois modos. Cor nunca é o único sinal de estado (acompanhar de ícone ou texto).
- Dados/gráficos: uma série por aparelho; cores categóricas distintas das de estado (bateria baixa não pode parecer uma série). Paleta a validar no protótipo.

### 3.2 Tipografia
- Display/heading: SF Pro (sistema) · Corpo: SF Pro · Mono: SF Mono, só para valores técnicos
- Carregamento: fonte do sistema, sem arquivo próprio.

| Estilo | Tamanho / linha | Peso | Uso |
|---|---|---|---|
| `display` | 34 / 40 pt | semibold, números tabulares | Porcentagem grande (hoje sem uso: o widget usa anéis, com o percentual embaixo só no médio, `text.ringPercent` na §3.8) |
| `h1` | 22 / 28 pt | semibold | Título de janela de ajustes |
| `h2` | 17 / 22 pt | semibold | Seção |
| `h3` | 13 / 18 pt | semibold | Nome do aparelho |
| `body` | 13 / 18 pt | regular | Texto corrido |
| `body-sm` | 11 / 14 pt | regular | Apoio |
| `caption` | 10 / 13 pt | regular | Hora da leitura, legendas do gráfico |
| `code` | 11 / 14 pt | regular, mono | Valores técnicos (ids) |

- Medida de linha: 45-75 caracteres no texto corrido. Números sempre com `monospacedDigit` para não tremer ao atualizar.

### 3.3 Espaçamento e layout
- Grid base: 4 pt. Escala: 4, 8, 12, 16, 24, 32. Sem número mágico fora da escala.
- Popover: largura 320 pt. Widget: medidas e margens do Baterias na §3.8; o grande e o estado vazio usam as margens do sistema.
- Breakpoints: N/A (macOS); o widget tem três famílias (pequeno, médio, grande). Abordagem: desktop.
- Densidade: confortável. Alvo de clique mínimo: 24 x 24 pt.

### 3.4 Forma e elevação
- Raio: sm 6, md 10, lg 14 (acompanha o widget do sistema) · Borda: 1 pt, `border`
- Sombra/elevação: nenhuma própria; usar o material do sistema (§3.7).
- Z-index: N/A.

### 3.5 Movimento
- Durações: rápida 120 ms, base 200 ms · Easing: ease-out do sistema.
- Movimento só comunica mudança de estado (nível mudou, começou a carregar). Respeitar "Reduzir movimento" do SO.

### 3.6 Iconografia e imagem
- Biblioteca de ícones: SF Symbols (`computermouse`, `keyboard`, `laptopcomputer`, `headphones`, `battery.*`, `bolt.fill`, `cable.connector`) · Tamanhos: 12, 16, 20 pt, e 24 pt no anel do widget (`icon.ring`) · Traço: regular.
- Imagens/ilustração: sem ilustração; texto alternativo obrigatório em qualquer imagem.

Ícones próprios (SF Symbols personalizados, #65). Até lá, o selo é o `TransportBadge` ao lado ou embaixo do ícone.
- Formato: `.svg` exportado do template do app SF Symbols, importado sem aviso no app e guardado como Symbol Image Set em `LogiBattery/Assets.xcassets` (alvos do app e do widget). Uso: `Image("lb.mouse.bluetooth")`.
- Nome: `lb.<aparelho>.<conexão>`. Conjunto: `lb.mouse.bluetooth`, `lb.mouse.receiver`, `lb.keyboard.bluetooth`, `lb.keyboard.receiver`, `lb.headphones.bluetooth`. O Mac segue `laptopcomputer`, sem selo.
- Desenho: o SF Symbol do aparelho é a base; o selo (raio do Bluetooth, igual ao `BluetoothRune`, ou `cable.connector` para o receptor) fica dentro do desenho, com recorte de folga em volta, no peso regular.
- Posição do selo: fone no arco da cabeça; mouse na traseira; teclado escolhido no protótipo da #65.
- Monocromático (modo template): o sistema pinta o símbolo inteiro no `.accented` e no `.vibrant`.
- O selo não vira texto: o rótulo do VoiceOver continua "nome, percentual", e a conexão entra no rótulo só onde já entra hoje.

### 3.7 Materiais e Liquid Glass
- Widget: fundo só por `containerBackground(_:for: .widget)` (macOS 14+). No estilo padrão, o fundo é escolhido no spike da #64 entre `.fill.tertiary` (atual), `Color.clear`, `.thinMaterial` e vidro. Nos estilos claro e tingido, o macOS troca esse fundo por vidro sozinho: o widget nunca desenha vidro próprio.
- Modos de renderização (`@Environment(\.widgetRenderingMode)`):
  - `.fullColor`: cores completas, o padrão.
  - `.accented` (estilos claro e tingido do Liquid Glass): o sistema pinta de branco o conteúdo primário e o grupo de destaque. O anel de progresso leva `widgetAccentable()`; a trilha fica em baixa opacidade para continuar visível; o ícone usa `widgetAccentedRenderingMode(.accented)`. O nível baixo fica no comprimento do anel e no número, como no Baterias.
  - `.vibrant` (mesa fora de foco): o sistema dessatura tudo; a hierarquia sai da opacidade (primário, secundário), não da cor.
- Fundo removido: `@Environment(\.showsWidgetContainerBackground)` falso quer dizer sem fundo; nada pode depender do contraste do fundo.
- Popover e janelas: `glassEffect(_:in:)` nas seções no macOS 26+ e `.regularMaterial` antes, sempre atrás de `if #available(macOS 26, *)` (alvo mínimo macOS 14). Nunca vidro sobre vidro.
- Matriz de verificação em `docs/TESTING.md` (#64): estilo padrão, escuro, claro e tingido; sistema claro e escuro; mesa ativa e inativa.

### 3.8 Medidas do widget
Medidas do widget Baterias da Apple no macOS 27, tiradas de prints de 2026-11-03 (1 px = 1 pt) com contagem de pixel e conferidas com o nosso widget ao lado. Tolerância: ±1 pt. Implementação: `RingMetrics` em `LogiBatteryWidget/LogiBatteryWidget.swift` (#63).

| Token | Pequeno | Médio | Regra |
|---|---|---|---|
| `ring.small` / `ring.medium` (diâmetro externo) | 64 pt | 62 pt | grade 2x2 no pequeno; 4 colunas iguais no médio (passo 81 pt) |
| `ring.stroke` | 6 pt | 6 pt | ponta redonda; trilha em `quaternary` |
| `ring.gap` | 12 pt | sobra das 4 colunas | entre anéis |
| `icon.ring` | 24 pt | 24 pt | cor primária, centro do anel, igual nos dois tamanhos |
| `text.ringPercent` | sem percentual | 16 pt semibold, `monospacedDigit` | topo do dígito 18 pt abaixo do anel, cor primária; anel e texto centralizados na vertical |
| `widget.margin` | o que sobra, com a grade de 140 pt centrada | 10 pt nas laterais | `.contentMarginsDisabled()`; o grande e o vazio seguem com as margens do sistema (`widgetContentMargins`) |

## 4. Componentes

Todo componente documenta: anatomia, variantes, tamanhos, estados e comportamento. Estados obrigatórios: padrão, hover, foco visível, ativo/pressionado, desabilitado, carregando, erro, vazio (quando faz sentido).

| Componente | Variantes | Tamanhos | Estados cobertos | Código | Teste |
|---|---|---|---|---|---|
| Botão | primary, secondary, ghost | sm, md | todos | `LogiBattery/UI/Components/` | componente + visual |
| Switch e stepper (ajustes) | padrão | md | padrão, foco, desabilitado | `LogiBattery/UI/Components/` | componente + a11y |
| Cartão de aparelho | mouse, teclado, Mac, fone, genérico | popover, widget | ok, baixo, crítico, carregando, cheio, sem leitura | `LogiBattery/UI/Components/` | componente + visual |
| Indicador de bateria | célula + número | sm, md, lg | ok, baixo, crítico, carregando, cheio, sem leitura | `LogiBattery/UI/Components/` | componente + visual |
| Gráfico de histórico | linha por aparelho | popover, widget grande | vazio, carregando, dados | `LogiBattery/UI/Components/` | visual |
| Popover | lista | 320 pt | vazio, erro de permissão | `LogiBattery/UI/` | componente + E2E |
| Banner de permissão | aviso | md | padrão | `LogiBattery/UI/Components/` | componente + a11y |
| Widget | small, medium, large | 3 famílias | com dados, sem dados, desatualizado | `LogiBatteryWidget/` | visual |
| Grade de anéis (widget) | 2x2 (pequeno), 4x1 (médio) | 4 posições fixas | com aparelho, posição vazia, leitura velha | `LogiBatteryWidget/` (`RingWidget`, `RingSlot`) | visual |

Por componente, registrar em `design/components.md` a anatomia e a regra de uso; o que não tiver variante documentada não existe.

## 5. Padrões de interface
- Formulários (ajustes): rótulo sempre visível, mudança vale na próxima leitura, sem botão "salvar".
- Feedback: banner no popover para permissão e erro; notificação do sistema para bateria baixa e carga cheia; sem toast.
- Carregamento: placeholder no lugar do número depois de 300 ms; nunca mostrar zero enquanto lê.
- Estado vazio: explica que nenhum aparelho Logitech foi achado e como parear ou ligar o receptor.
- Estado de erro: diz o que houve (ex.: permissão negada) e leva ao painel de Privacidade.
- Navegação: ícone na barra de menu abre o popover; ajustes em janela própria; profundidade máxima 2.
- Listas: aparelhos ordenados do menor para o maior nível; sem busca nem paginação.
- Widget: três tamanhos. Pequeno e médio usam a grade de anéis com 4 posições fixas (2x2 e 4x1), Mac primeiro e o resto do menor para o maior nível; posição sem aparelho mostra só o anel vazio (`quaternary`, fora do VoiceOver). O ícone do aparelho (`computermouse`, `keyboard`, `laptopcomputer`, `headphones`) fica no centro do anel, em cor primária. Medidas do Baterias da Apple na §3.8 (#63). Pequeno: selo de conexão (Bluetooth ou receptor; o Mac não tem) dentro do anel, logo abaixo do ícone, e sem percentual (lotava a grade; o VoiceOver lê o número). Médio, igual ao médio da Apple: percentual semibold em cor primária embaixo do anel, com o selo ao lado do percentual (#60). O grande segue com a lista e o gráfico. Aprovado por Lucas em 2026-11-03.
- Leitura velha: aparelho sem leitura nova há mais de 30 min (dormindo ou fora de alcance) continua na lista com a hora da última leitura, e anel, número e célula ficam em `muted` (`.secondary`), no widget e no popover. Volta à cor na primeira leitura nova. Aprovado por Lucas em 2026-11-03.

## 6. Acessibilidade
- Meta: WCAG 2.2 AA.
- Navegação completa por teclado no popover e nos ajustes, ordem de foco lógica, foco sempre visível.
- Rótulos de acessibilidade falados ("Mouse, 42 por cento, carregando"), Dynamic Type e "Aumentar contraste" respeitados.
- Alvos de clique com tamanho mínimo; texto redimensionável sem perda.
- Verificação: Accessibility Inspector e `performAccessibilityAudit` nos testes de UI, mais passada manual com VoiceOver antes de release (ver `docs/TESTING.md`).

## 7. Conteúdo e microcopy
- Idioma da UI: pt-BR e inglês · Tratamento: você, informal · Tom: direto e calmo.
- Mensagens: curtas, no ativo, sem culpar o usuário; erro diz causa e próximo passo.
- Formatos: datas e horas do sistema, relativas quando recentes ("há 3 min"); porcentagem inteira "42%"; números do locale.
- Capitalização: só a primeira palavra em botões e títulos.
- Opção que esconde algo diz na legenda como trazer de volta (ex.: "Mostrar ícone na barra de menus": "Escondido, o app segue lendo e atualizando o widget. Para ver o ícone de novo, abra o LogiBattery pelo Spotlight ou pelo Finder.").
- Internacionalização: strings em `Localizable.xcstrings` (String Catalog), pt-BR e en desde o início.

## 8. Faça e não faça
Faça:
- Comparar com o Baterias da Apple lado a lado e medir antes de dar por pronto (±1 pt na §3.8).
- Usar cor semântica, material e SF Symbol do sistema; ícone próprio só no formato da §3.6.
- Testar os três modos de renderização (§3.7) em todo PR que mexe no widget.
- Um único primário por tela; hierarquia clara entre primário, secundário e terciário.
- Espaçamento consistente com a escala (§3.3) ou com os tokens da §3.8.

Não faça:
- Degradê arco-íris, emoji decorativo, vidro próprio no widget ou vidro sobre vidro.
- Cartão dentro de cartão, sombra em tudo, ícone genérico para preencher espaço.
- Número mágico fora da escala e dos tokens.
- Cor própria fora dos tokens de nível.
- Selo de conexão solto onde o símbolo próprio já existe.

## Fluxo de protótipo e aprovação

Nenhuma tela é desenvolvida sem protótipo aprovado. O inventário e o status de cada tela ficam em [design/telas.md](design/telas.md); o passo a passo em [design/README.md](design/README.md).

1. Definir a tela a partir de uma história do `docs/PRD.md`.
2. Prototipar usando só tokens e componentes deste arquivo. Ferramenta: HTML em `design/prototypes/` (Figma se o Lucas pedir).
3. Cobrir os estados (padrão, vazio, carregando, erro), tema claro e escuro, e os três tamanhos do widget.
4. Lucas revisa e aprova; a data e o link entram em `design/telas.md`.
5. Só então implementar. A implementação é comparada com o protótipo (captura em `design/screenshots/`) e o teste visual/E2E da tela referencia o aprovado.
6. Componente ou token novo exigido pela tela entra neste arquivo antes (ou junto) e passa pela mesma aprovação.

## Referências visuais
- Widget Baterias e popover de Bluetooth do macOS (alvo de integração visual).
- Apple, "Optimizing your widget for accented rendering mode and Liquid Glass" (WidgetKit): modos de renderização e vidro.
- [Meliwat/awesome-ios-design-md](https://github.com/meliwat/awesome-ios-design-md), `apple-fitness/DESIGN-swiftui.md`: anel de ponta redonda com trilha em baixa opacidade.

## Histórico
- 2026-10-27: criação do design system (rascunho).
- 2026-11-03: leitura com mais de 30 min em cinza (widget e popover).
- 2026-11-03: grade de anéis no widget pequeno (2x2, sem percentual) e médio (4x1); selo de conexão dentro do anel; ícones de Mac e fone (#55).
- 2026-11-03: opção de esconder o ícone da barra de menus, com a legenda de como voltar (#56).
- 2026-11-03: médio no visual do médio da Apple, selo ao lado do percentual (#60).
- 2026-11-03: Apple nativa como referência no formato do VoltAgent: visão geral, ícones próprios, materiais e Liquid Glass, medidas do widget, faça e não faça (#62).
- 2026-11-03: widget pequeno e médio nas medidas do Baterias (anel de 64 e 62 pt, ícone de 24 pt em cor primária, percentual de 16 pt), conferidas em print ao lado do da Apple; protótipos com os SF Symbols de verdade (#63).

## Ícone do app
Opção A aprovada por Lucas em 2026-10-29: anel de carga verde (gradiente `#5EE59A` a `#1F9D55`) sobre fundo escuro `#1C2333`/`#0B0F19`, com raio branco no centro. Fonte em `design/icon/appicon.svg` (1024 pt, margem de 100 pt); os PNGs de `LogiBattery/Assets.xcassets/AppIcon.appiconset` saem dela com `rsvg-convert`.
