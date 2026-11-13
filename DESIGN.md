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
- Popover: largura padrão 320 pt (configurável nos Ajustes de 320 a 480 pt, passo de 20 pt, para acomodar nomes longos). Widget: medidas e margens do Baterias na §3.8; o grande e o estado vazio usam as margens do sistema.
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

Ícones próprios (SF Symbols personalizados, #65 e #75), no widget (pequeno, médio e grande) e no popover. `Device.symbol` escolhe o símbolo; todo aparelho com conexão tem símbolo próprio, e não há `TransportBadge` separado.
- Formato: template estático do SF Symbols com o peso Regular nas escalas S, M e L (`actool` exige as três; o app usa só o peso regular), como Symbol Image Set em `LogiBattery/Symbols.xcassets` (alvos do app e do widget). Gerado por `design/symbols/make.py`, que exporta o template da Apple pelo CLI do app SF Symbols e compõe o selo com skia-pathops; não editar o `.svg` à mão.
- Nome: `lb.<aparelho>.<conexão>`. Conjunto: `lb.mouse.bluetooth`, `lb.mouse.receiver`, `lb.keyboard.bluetooth`, `lb.keyboard.receiver`, `lb.headphones.bluetooth`, `lb.headphones.receiver`, `lb.other.bluetooth`, `lb.other.receiver` (base `dot.radiowaves.left.and.right`). O Mac segue `laptopcomputer`, sem selo.
- Desenho: o SF Symbol do aparelho é a base; o selo (raio do Bluetooth com os pontos do `BluetoothRune`, 44 unidades de altura e traço de 5,5, ou `cable.connector` com 46 de altura para o receptor) fica sobre o desenho, com recorte de folga de 5 unidades em volta, no peso regular.
- Posição do selo: canto de baixo à direita em todos os aparelhos, avançando para fora do desenho base, como os `.badge` da Apple (escolha do Lucas em 2026-11-03, protótipo T01).
- O selo não vira texto: o rótulo do VoiceOver continua "nome, percentual" no anel; na lista do widget grande a conexão entra pelo rótulo do símbolo, e no popover o símbolo fica oculto (a conexão já está no texto).

### 3.7 Materiais e Liquid Glass
- Widget: fundo `containerBackground(.clear, for: .widget)`. Sobra a base do próprio sistema: cinza-escura no sistema escuro e branca no claro. Nos estilos translúcido e tonalizado, o macOS troca essa base por vidro sozinho. O widget nunca desenha vidro próprio.
- Spike da #64 (macOS 27, 2026-11-03), medido em print no estilo tom escuro:
  - `.fill.tertiary`, `.thinMaterial`, `.ultraThinMaterial`, `glassEffect` (`.regular` e `.clear`), `.background` e `.windowBackground` saem todos opacos;
  - o vidro só aparece quando é o sistema que troca o fundo (translúcido, tonalizado, atenuado);
  - o Baterias da Apple mostra o papel de parede no padrão e no tom escuro porque a base dele é do sistema, só para widget da Apple; o Stats, de terceiro, também fica opaco;
  - `.clear` deixa a base mais escura e mais próxima da Apple, sem cor fixa nossa.
- Modos de renderização (`@Environment(\.widgetRenderingMode)`):
  - `.fullColor`: cores completas, o padrão.
  - `.accented` (estilos translúcido e tonalizado): o sistema pinta todo shape de uma cor (branco no translúcido, a cor do tom no tonalizado). Diferente do Baterias, o anel de progresso e a barra `BatteryCell` mantêm a cor do nível: no macOS 15+ eles são desenhados como imagem (`Image(size:renderer:)`) com `widgetAccentedRenderingMode(.fullColor)`, sem checar `widgetRenderingMode` (no macOS 27 esses estilos não chegam como `.accented`). Trilha, ícone e texto seguem a cor do sistema. Leitura velha e macOS 14 usam o shape com `widgetAccentable()`.
  - `.vibrant` (mesa fora de foco): o sistema dessatura tudo; a hierarquia sai da opacidade (primário, secundário), não da cor.
- Fundo removido: `@Environment(\.showsWidgetContainerBackground)` falso quer dizer sem fundo; nada pode depender do contraste do fundo.
- Popover e janelas: `glassEffect(_:in:)` nas seções no macOS 26+ e `.regularMaterial` antes, sempre atrás de `if #available(macOS 26, *)` (alvo mínimo macOS 14). Nunca vidro sobre vidro.
- Matriz de verificação com prints em `docs/TESTING.md` §3 (#64): estilo padrão, tom escuro, translúcido e tonalizado; sistema claro e escuro; widgets atenuados.

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
| Linha de ajuste com ícone (#67) | quadrado colorido de 24 pt, raio 6 (`r-sm`), SF Symbol branco de 14 pt; cores `blue`, `orange`, `red`, `green`, `purple`, `gray` | md | padrão, foco | `LogiBattery/UI/SettingsView.swift` (`Form(.grouped)` + `Section`) | componente + a11y |
| Seletor em menu nos ajustes (#115, aprovado em 2026-11-04) | `Picker` em menu à direita da linha com ícone; duração (Na hora, 5, 15, 30 min, 1, 2, 6, 12, 24, 48 h, 7 dias, rótulos de `Duration` localizados, 0 = "Na hora") e escopo do Esquecer (Só leitura cinza, Cinza e verde). Alternativa B, stepper com unidade sobre a mesma lista, descartada pelo Lucas | md, valor com largura mínima de 104 pt | padrão, foco, aberto, desabilitado (linha sem efeito, a dica diz por quê), ajustado (aviso na dica) | `LogiBattery/UI/SettingsView.swift` | unitário (regra cinza <= sumir) + componente + a11y |
| Cartão de aparelho | mouse, teclado, Mac, fone, genérico | popover, widget | ok, baixo, crítico, carregando, cheio, sem leitura | `LogiBattery/UI/Components/` | componente + visual |
| Indicador de bateria | célula + número | sm, md, lg | ok, baixo, crítico, carregando, cheio, sem leitura | `LogiBattery/UI/Components/` | componente + visual |
| Gráfico de histórico | linha por aparelho | popover, widget grande | vazio, carregando, dados | `LogiBattery/UI/Components/` | visual |
| Popover | lista | 320 pt | vazio, erro de permissão | `LogiBattery/UI/` | componente + E2E |
| Seção de vidro do popover (#66) | `glassEffect` (macOS 26+), `.regularMaterial` (antes) | 320 pt, raio 14 | padrão, vazio, carregando, erro | `LogiBattery/UI/Components/` | componente + visual |
| Faixa de anéis do popover (#66, direção B) | anéis do widget médio no topo (ícone próprio com selo e percentual), lista de aparelhos embaixo | 320 pt, 4 posições fixas | com aparelho, posição vazia, leitura velha | `LogiBattery/UI/Components/` | componente + visual |
| Seletor segmentado do ANC (T12, #150) | três botões de largura igual dentro de um trilho `.quaternary` (raio 8, 2 pt de respiro); selecionado em `accentColor` com texto branco e peso semibold, demais em `.primary`. Existe porque o `Picker` segmentado nativo do macOS não estica até a largura da linha | linha do grupo de controles, 468 pt | padrão, selecionado, aplicando (controles desabilitados até o eco do fone), somente leitura | `QCYBattery/QCYView.swift` | componente + a11y (grupo `.contain` com rótulo, trait `.isSelected` no botão marcado) |
| Anel dividido e linha com lados do fone QCY (#142, T13, aprovado em 2026-11-13) | anel de 56 pt dividido ao meio (metade esquerda L, direita R, de baixo para cima, vão de 2% nas pontas), texto "90 · 85" embaixo; tooltip "E 100%" acima do anel só com leitura do estojo; na lista, segunda faixa com L, R e E (célula de 28 pt) | popover 320 pt | padrão, lado baixo, um lado só ("—", nunca 0%), lado carregando (`info`), cinza, com estojo | `LogiBattery/UI/DeviceList.swift` (`HalfRing`, `CaseTooltip`), `LogiBattery/UI/Components/DeviceRow.swift` | componente + a11y |
| Menu de contexto da linha e aviso Desfazer (#113) | menu nativo com um item "Esquecer <nome>" só em leitura mantida e cinza; aviso de 8 s no popover com "<nome> esquecido" e Desfazer, sem janela de confirmação | linha do popover, seção de vidro | padrão, foco, linha sem ação (sem menu) | `LogiBattery/UI/DeviceList.swift` | unitário (`DeviceListViewModelTests`) + a11y |
| Banner de permissão | aviso | md | padrão | `LogiBattery/UI/Components/` | componente + a11y |
| Widget | small, medium, large | 3 famílias | com dados, sem dados, desatualizado | `LogiBatteryWidget/` | visual |
| Grade de anéis (widget) | 2x2 (pequeno), 4x1 (médio) | 4 posições fixas | com aparelho, posição vazia, leitura velha | `LogiBatteryWidget/` (`RingWidget`, `RingSlot`) | visual |

Por componente, registrar em `design/components.md` a anatomia e a regra de uso; o que não tiver variante documentada não existe.

## 5. Padrões de interface
- Formulários (ajustes): rótulo sempre visível, mudança vale na próxima leitura, sem botão "salvar".
- Ajustes que dependem um do outro (#115, aprovado em 2026-11-04): o que o usuário mexeu por último vale e o outro valor é puxado junto (ficar cinza nunca passa de sumir), sem bloquear o menu. A linha puxada troca a dica por "Ajustado de X para Y: <motivo>" em `foreground` (a dica normal é `muted`), role de status para o VoiceOver, até a próxima mudança na seção. Linha sem efeito (sem leitura mantida) fica desabilitada e a dica explica o motivo.
- Feedback: banner no popover para permissão e erro; notificação do sistema para bateria baixa e carga cheia; sem toast.
- Carregamento: placeholder no lugar do número depois de 300 ms; nunca mostrar zero enquanto lê.
- Estado vazio: explica que nenhum aparelho Logitech foi achado e como parear ou ligar o receptor.
- Estado de erro: diz o que houve (ex.: permissão negada) e leva ao painel de Privacidade.
- Navegação: ícone na barra de menu abre o popover; ajustes em janela própria; profundidade máxima 2.
- Listas: aparelhos ordenados do menor para o maior nível; sem busca nem paginação.
- Widget: três tamanhos. Pequeno e médio usam a grade de anéis com 4 posições fixas por página (2x2 e 4x1), Mac primeiro e o resto do menor para o maior nível; posição sem aparelho mostra só o anel vazio (`quaternary`, fora do VoiceOver). O ícone do aparelho fica no centro do anel, em cor primária, com o selo de conexão recortado no canto de baixo à direita do próprio símbolo (`lb.*`, #65 e #75; o Mac não tem selo). Medidas do Baterias da Apple na §3.8 (#63). Pequeno: sem percentual (lotava a grade; o VoiceOver lê o número). Médio, igual ao médio da Apple: percentual semibold em cor primária embaixo do anel, com paginação a partir do 5º aparelho via `AppIntent` (#79). O grande segue com a lista e o gráfico até 4 aparelhos; com 5 ou 6 aparelhos mostra até 6 linhas sem gráfico numa página só, e a partir do 7º pagina de 6 em 6 linhas (#79). Aprovado por Lucas em 2026-11-03.
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

## 9. Site (web)

Landing pública em `site/` (T10, #92), HTML/CSS/JS estático no GitHub Pages. Vale só para o site; app, widget e popover seguem as seções 1 a 8. Tokens documentados aqui são os do `:root` de `site/index.html`; o código é a implementação. Status: aprovada em 2026-11-03 (#106).

### 9.1 Visão geral
- Público: quem usa mouse e teclado Logitech no Mac e quer a bateria de relance; chega por busca ou link, decide em segundos.
- Personalidade: a do app (discreta, nativa, calma). A página parece uma página da Apple, não um painel de marketing.
- Um único primário por tela: o botão de download. Apoio (Pix) é secundário.
- Relação com a Apple: o app herda cores, materiais e ícones do sistema (cores semânticas do `NSColor`, Liquid Glass, SF Symbols); o site não tem acesso a isso na web e **imita** a linguagem da Apple. A paleta vem do apple.com (`#f5f5f7`, `#1d1d1f`, `#6e6e73`), a fonte é a pilha do sistema, o botão é em pílula e a página é plana, sem material nem sombra.
- Desvio deliberado do `systemBlue` do macOS (`#007AFF` no claro, `#0A84FF` no escuro): `--primary` é `#0a64f0` e `#3b8bff`, ajustados para passar o contraste de texto e de link (§9.2). Não trocar pelo `systemBlue` sem refazer a medição.
- Cor de nível (`ok`) só aparece quando o assunto é bateria; nunca como enfeite.

### 9.2 Cor
Tokens CSS no `:root`; o modo escuro redefine os mesmos nomes em `@media (prefers-color-scheme: dark)`. `color-scheme: light dark` declarado. Contraste medido com a fórmula WCAG 2.2.

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `--bg` | #f5f5f7 | #1c1c1e | Fundo da página, fundo do `code` |
| `--surface` | #ffffff | #2a2a2d | Cartão, seletor, bloco de apoio, botão secundário |
| `--fg` | #1d1d1f | #f5f5f7 | Texto principal |
| `--muted` | #6e6e73 | #a1a1a6 | Texto de apoio, notas, rodapé |
| `--border` | #d2d2d7 | #4d4d52 | Divisórias e bordas |
| `--primary` | #0a64f0 | #3b8bff | Botão principal e links |
| `--border-control` | #86868b | #76767b | Borda de controle (seletor, botão secundário), >= 3:1 |
| `--primary-fg` | #ffffff | #000000 | Texto sobre `--primary` |
| `--shot` | #c9d4e6 | #2c3a52 | Fundo da moldura de print |
| `--ok` | #1f9d55 | #34c77b | Reservado a nível de bateria (hoje sem uso visível) |
| `--qr-bg` | #ffffff | #ffffff | Fundo do QR Code (precisa ser claro nos dois modos) |

Contraste medido:

| Par | Claro | Escuro | Exigência | Resultado |
|---|---|---|---|---|
| `--fg` / `--bg` | 15,46 | 15,63 | 4,5 | ok |
| `--muted` / `--bg` | 4,66 | 6,61 | 4,5 | ok |
| `--muted` / `--surface` | 5,07 | 5,56 | 4,5 | ok |
| `--primary` / `--bg` (link) | 4,71 | 5,12 | 4,5 | ok |
| `--primary-fg` / `--primary` (botão) | 5,13 | 6,32 | 4,5 | ok |
| `--border-control` / `--bg` | 3,33 | 3,77 | 3 | ok |
| `--border-control` / `--surface` | 3,62 | 3,17 | 3 | ok |

`--border` (1,38 e 2,02 contra `--bg`) fica só em borda decorativa de cartão e bloco de apoio; controle usa `--border-control`.

### 9.3 Tipografia
- Pilha do sistema, sem arquivo de fonte: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif`. Mono: `ui-monospace, SFMono-Regular, Menlo, monospace`, só para a chave Pix.

| Estilo | Tamanho / linha | Peso | Uso |
|---|---|---|---|
| `hero` | `clamp(32px, 6vw, 52px)` / 1,1 | bold, tracking -0,02em | `h1` |
| `h2` | 28 / 1,2 | bold, tracking -0,01em | Seção |
| `h3` | 17 | bold | Título de cartão |
| `lead` | 19 | regular | Subtítulo do hero |
| `body` | 17 / 1,5 | regular | Texto corrido |
| `body-sm` | 15 | regular | Texto de cartão |
| `note` | 14 | regular | Nota, rodapé, seletor |
| `code` | 13 | regular, mono | Chave Pix |

- Medida de linha 45 a 75 caracteres (`max-width: 56ch` no lead).

### 9.4 Espaço, layout e forma
- Escala: 4, 8, 12, 16, 24, 32, 48. Valores fora da escala (20, 6, 10) saem na refatoração, exceto onde o espaço é interno ao componente e documentado.
- Container `.wrap`: 960 px, gutter lateral 16 px. Grade de recursos `repeat(auto-fit, minmax(240px, 1fr))`, de prints `minmax(280px, 1fr)`.
- Breakpoints: mobile a partir de 360 px, tablet 768, desktop 960. Sem rolagem horizontal em nenhum.
- Raios: `sm` 8 (seletor, QR), `md` 12 (print), `lg` 14 (cartão, bloco de apoio), `xl` 20 (moldura), `pill` 999 (botão). Sem sombra própria.
- Movimento: 120 ms (hover) e 200 ms (troca de texto), `ease-out`. `prefers-reduced-motion: reduce` desliga qualquer transição.

### 9.5 Componentes

| Componente | Classe | Variantes | Estados |
|---|---|---|---|
| Botão | `.btn` | primário (`--primary`), secundário (`.btn.alt`, `--surface` com borda) | padrão, hover (85% de opacidade), foco visível, ativo, copiado (rótulo "Copiado") |
| Seletor de idioma | `select#lang` | padrão | padrão, foco visível; troca atualiza `lang` do `html` e guarda a escolha |
| Cartão de recurso | `.card` | título + frase | padrão |
| Grade de recursos | `.grid` | 4 cartões | colapsa para 1 coluna no mobile |
| Moldura de print | `.shot` | uma ou duas por linha (`.shots`) | padrão; imagem com `alt` descritivo |
| Bloco de apoio | `.support` | texto + botão + chave + QR Code | padrão, copiado |
| Nota | `.note` | legenda | padrão |
| Cabeçalho | `header` | marca + seletor | padrão |
| Rodapé | `footer` | link do código + licença | padrão |

Regra: componente sem linha aqui não existe; novo componente entra nesta tabela antes do HTML.

### 9.6 Acessibilidade (WCAG 2.2 AA)
- Foco visível em todo interativo: `:focus-visible` com contorno de 2 px em `--primary` e 2 px de afastamento.
- Alvo de toque >= 44 px (`--target`), botões e seletor com `min-height`.
- `alt` descritivo em todo print, traduzido nos 3 idiomas (chaves `alt1` a `alt3`); `alt` do QR Code já presente.
- `lang` do `html` acompanha o idioma escolhido; `aria-label` do seletor bilíngue.
- Teclado completo: seletor, download e "Copiar chave" sem mouse; ordem de foco = ordem visual.
- Estrutura: um `main` envolvendo hero, recursos, prints e apoio; cabeçalho e rodapé fora dele; títulos de cartão são `h2` com a classe `.h3` (estilo de §9.3), para não pular nível depois do `h1`.
- Verificação: Lighthouse (acessibilidade >= 95, medido 100 em mobile e desktop) e conferência em pt-BR, en e es, claro e escuro, a 360 px, sem rolagem horizontal.

### 9.7 Conteúdo e i18n
- Idiomas: pt-BR, en, es; detecção por `navigator.language`, escolha manual guardada em `localStorage`.
- Todo texto vem do objeto `T` por `data-i`; nenhum texto fixo no HTML além da marca e do nome do projeto.
- Tom: direto e calmo, sem exclamação e sem superlativo. Capitalização: só a primeira palavra em botões e títulos.
- Rótulo de botão cabe em uma linha nos 3 idiomas em 360 px.
- A chave Pix e o QR Code são gerados por `design/pix/make.py` e conferidos antes de publicar.

### 9.8 Prints do site
- Origem: os protótipos aprovados (`design/prototypes/t02-widget-medio.html`, `t03-widget-grande.html`, `t04-popover.html`), com nomes e valores fictícios; o site público não mostra dado real nem o nome do Mac do Lucas. Capturas do app rodando ficam para depois de existir um modo demo no app.
- Recorte: só o widget (médio e grande) ou o popover (sem a barra de menus), sem título, sem moldura de protótipo e sem sombra; cantos arredondados com fundo transparente.
- Tamanho: @2x (largura 640 a 676 px), PNG. Um arquivo por tema: `<nome>-light.png` e `<nome>-dark.png`, escolhidos por `<picture>` com `prefers-color-scheme`.
- Onde: originais em `design/screenshots/site-<nome>-<tema>.png`, cópia publicada em `site/shots/<nome>-<tema>.png`.
- Como regenerar: Playwright com `deviceScaleFactor: 2`, escondendo `.tag` e `.menubar` e zerando `box-shadow`, e `screenshot` do primeiro `.widget` ou `.popover` de cada `.theme.light` e `.theme.dark` com `omitBackground`.
- `alt` descritivo traduzido nos 3 idiomas (§9.6).

### 9.9 Faça e não faça
Faça:
- Usar só tokens do `:root`; trocar de tema pelo `prefers-color-scheme`.
- Prints reais do app, com `alt` descritivo.
- Conferir contraste ao mudar qualquer cor.

Não faça:
- Valor literal de cor, raio ou espaço fora do `:root` e da escala.
- Biblioteca, fonte externa ou rastreador (a página não faz rede além do download e dos links).
- Segundo botão primário na mesma tela, gradiente, emoji decorativo.

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
- 2026-11-03: símbolos próprios com o selo de conexão no canto de baixo (`lb.*`), no widget e no popover (#65).
- 2026-11-03: fundo do widget transparente (base do sistema, vidro nos estilos translúcido e tonalizado), anel na cor do nível também no translúcido e no tonalizado (imagem em cor cheia) e matriz de estilos com prints; vidro do Baterias no estilo padrão é exclusivo da Apple (#64).
- 2026-11-03: todos os ícones com conexão usam símbolo próprio `lb.*` (`lb.other.*` e `lb.headphones.receiver`), sem `TransportBadge` separado (#75); popover na direção B com faixa de anéis no topo e seções em vidro (#66); paginação nos widgets médio e grande com `AppIntent` (#79); Ajustes no visual dos Ajustes do Sistema com ícones coloridos por linha (#67).
- 2026-11-03: seção 9 (site): tokens, tipografia, componentes e acessibilidade da landing, com contraste medido (#106).
- 2026-11-03: seção 9 explicita que o site imita a Apple (paleta do apple.com) em vez de herdar do sistema, e o desvio do `systemBlue` (#106).
- 2026-11-03: prints do site recortados dos protótipos aprovados, @2x, claro e escuro, com `<picture>` (#106).
- 2026-11-04: menu de contexto da linha e aviso Desfazer no popover, direção A aprovada (T11, #113).
- 2026-11-13: anel dividido ao meio e linha L/R(/E) do fone QCY no popover, tooltip do estojo (T13, #142).

## Ícone do app
Opção A aprovada por Lucas em 2026-10-29: anel de carga verde (gradiente `#5EE59A` a `#1F9D55`) sobre fundo escuro `#1C2333`/`#0B0F19`, com raio branco no centro. Fonte em `design/icon/appicon.svg` (1024 pt, margem de 100 pt); os PNGs de `LogiBattery/Assets.xcassets/AppIcon.appiconset` saem dela com `rsvg-convert`.

### Ícone do QCYBattery
Opção 2 aprovada por Lucas em 2026-11-13 (#140): par de fones esquerdo (branco) e direito (verde `#7FE3B0`) sobre o mesmo fundo escuro do LogiBattery. Fonte em `design/icon/qcy/appicon.svg`; os PNGs de `QCYBattery/Assets.xcassets/AppIcon.appiconset` saem dela com `rsvg-convert`.
