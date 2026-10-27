# LogiBattery — DESIGN.md

Design system do projeto. É a fonte única de identidade visual e de padrões de interface: o `/frontend-design` e o `/impeccable` leem este arquivo antes de gerar UI. Regras globais em `~/.claude/CLAUDE.md` valem; aqui só o que é deste repo.

Regra de fluxo: nenhuma tela é implementada antes de ter protótipo aprovado pelo Lucas (ver [Fluxo de protótipo e aprovação](#fluxo-de-protótipo-e-aprovação) e [design/telas.md](design/telas.md)). Mudança em token ou componente atualiza este arquivo no mesmo PR.

Status do design system: aprovada em 2026-10-27

## 1. Brand
- Produto: monitor de bateria de periféricos Logitech para macOS, em widget e barra de menu.
- Público: pessoa que trabalha no Mac o dia todo com mouse e teclado sem fio; consulta de relance, várias vezes ao dia.
- Personalidade: discreto, nativo, preciso, calmo.
- Conceito visual: um indicador de nível (a célula da bateria) como forma central; o número é o protagonista, a cor só sinaliza urgência.
- Referências que gosto: widget Baterias e Ajustes do macOS (nativo, legível, sem enfeite); Logi Options+ só como referência de informação, não de visual.
- Anti-referências: painel de gamer com RGB, gauge decorativo, tema que briga com o macOS.
- Logo / ícone: a definir em `design/brand/`; ícone de barra de menu como template image (monocromático, 18 pt), ícone do app em estilo macOS.

## 2. Princípios de design
- O número vem primeiro: porcentagem legível a 1 metro de distância, antes de qualquer decoração.
- Parecer parte do macOS: componentes, ícones (SF Symbols) e tipografia do sistema.
- Cor sinaliza estado, nunca é o único sinal: baixo e crítico também mudam ícone e texto.
- Aparelho sem leitura mostra a última conhecida com a hora, nunca um zero falso.

## 3. Tokens

Tokens vivem em código em `LogiBattery/UI/Tokens.swift` e no `Assets.xcassets` (cores com variante clara e escura). Este arquivo documenta; o código é a implementação. Componente nunca usa valor literal, só token.

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
| `warning` (nível baixo) | #B7791F | #F2B13C | Bateria abaixo do limite baixo |
| `danger` (nível crítico) | #C53030 | #FF6B6B | Bateria abaixo do limite crítico |
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
| `display` | 34 / 40 pt | semibold, números tabulares | Porcentagem no widget pequeno |
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
- Popover: largura 320 pt. Widget: margens do sistema.
- Breakpoints: N/A (macOS); o widget tem três famílias (pequeno, médio, grande). Abordagem: desktop.
- Densidade: confortável. Alvo de clique mínimo: 24 x 24 pt.

### 3.4 Forma e elevação
- Raio: sm 6, md 10, lg 14 (acompanha o widget do sistema) · Borda: 1 pt, `border`
- Sombra/elevação: nenhuma própria; usar o material do sistema.
- Z-index: N/A.

### 3.5 Movimento
- Durações: rápida 120 ms, base 200 ms · Easing: ease-out do sistema.
- Movimento só comunica mudança de estado (nível mudou, começou a carregar). Respeitar "Reduzir movimento" do SO.

### 3.6 Iconografia e imagem
- Biblioteca de ícones: SF Symbols (`computermouse`, `keyboard`, `battery.*`, `bolt.fill`) · Tamanhos: 12, 16, 20 pt · Traço: regular.
- Imagens/ilustração: sem ilustração; texto alternativo obrigatório em qualquer imagem.

## 4. Componentes

Todo componente documenta: anatomia, variantes, tamanhos, estados e comportamento. Estados obrigatórios: padrão, hover, foco visível, ativo/pressionado, desabilitado, carregando, erro, vazio (quando faz sentido).

| Componente | Variantes | Tamanhos | Estados cobertos | Código | Teste |
|---|---|---|---|---|---|
| Botão | primary, secondary, ghost | sm, md | todos | `LogiBattery/UI/Components/` | componente + visual |
| Switch e stepper (ajustes) | padrão | md | padrão, foco, desabilitado | `LogiBattery/UI/Components/` | componente + a11y |
| Cartão de aparelho | mouse, teclado, genérico | popover, widget | ok, baixo, crítico, carregando, cheio, sem leitura | `LogiBattery/UI/Components/` | componente + visual |
| Indicador de bateria | célula + número | sm, md, lg | ok, baixo, crítico, carregando, cheio, sem leitura | `LogiBattery/UI/Components/` | componente + visual |
| Gráfico de histórico | linha por aparelho | popover, widget grande | vazio, carregando, dados | `LogiBattery/UI/Components/` | visual |
| Popover | lista | 320 pt | vazio, erro de permissão | `LogiBattery/UI/` | componente + E2E |
| Banner de permissão | aviso | md | padrão | `LogiBattery/UI/Components/` | componente + a11y |
| Widget | small, medium, large | 3 famílias | com dados, sem dados, desatualizado | `LogiBatteryWidget/` | visual |

Por componente, registrar em `design/components.md` a anatomia e a regra de uso; o que não tiver variante documentada não existe.

## 5. Padrões de interface
- Formulários (ajustes): rótulo sempre visível, mudança vale na próxima leitura, sem botão "salvar".
- Feedback: banner no popover para permissão e erro; notificação do sistema para bateria baixa e carga cheia; sem toast.
- Carregamento: placeholder no lugar do número depois de 300 ms; nunca mostrar zero enquanto lê.
- Estado vazio: explica que nenhum aparelho Logitech foi achado e como parear ou ligar o receptor.
- Estado de erro: diz o que houve (ex.: permissão negada) e leva ao painel de Privacidade.
- Navegação: ícone na barra de menu abre o popover; ajustes em janela própria; profundidade máxima 2.
- Listas: aparelhos ordenados do menor para o maior nível; sem busca nem paginação.
- Widget: três tamanhos; o pequeno mostra o aparelho mais crítico, o médio até 3, o grande a lista e o gráfico.

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
- Internacionalização: strings em `Localizable.xcstrings` (String Catalog), pt-BR e en desde o início.

## 8. Regras (anti "AI slop")
- Sem degradê arco-íris, emoji decorativo ou glassmorphism sem propósito.
- Sem cartão dentro de cartão, sem sombra em tudo, sem ícone genérico para preencher espaço.
- Um único primário por tela; hierarquia clara entre primário, secundário e terciário.
- Espaçamento consistente com a escala; sem números mágicos.
- Sem cor própria fora dos tokens de nível; o resto vem do sistema.

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

## Histórico
- 2026-10-27: criação do design system (rascunho).
