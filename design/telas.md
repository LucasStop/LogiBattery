# Inventário de telas — LogiBattery

Fluxo e regras em [README.md](README.md). Tela só vai para desenvolvimento com status `aprovada`.

| ID | Tela / fluxo | História (PRD) | Estados prototipados | Protótipo | Status | Aprovada em | Notas |
|---|---|---|---|---|---|---|---|
| T01 | Widget pequeno | US-05, US-13 | padrão, sem dados, desatualizado | prototypes/t01-widget-pequeno.html | implementada | 2026-11-03 | 4 posições em anéis 2x2, anel vazio onde falta aparelho; ícone no centro com o selo de conexão no próprio símbolo, no canto de baixo à direita (símbolos `lb.*`, aprovado em 2026-11-03, #65 e #75, sem `TransportBadge` separado); sem percentual (revisado em 2026-11-03, pedido do Lucas, #55). Anel cinza para leitura com mais de 30 min. Medidas do Baterias da Apple (DESIGN.md §3.8, #63): anel de 64 pt, vão de 12, ícone de 24 pt em cor primária |
| T02 | Widget médio | US-05, US-13 | padrão, sem dados, desatualizado | prototypes/t02-widget-medio.html | implementada | 2026-11-03 | Anéis numa linha 4x1 no visual do médio da Apple: ícone e percentual em cor primária, selo de conexão no próprio símbolo em todos os aparelhos (#65 e #75, sem `TransportBadge` separado). Anel cinza para leitura com mais de 30 min. Medidas do Baterias da Apple (DESIGN.md §3.8, #63): 4 colunas iguais, anel de 62 pt, ícone de 24 pt, percentual de 16 pt |
| T03 | Widget grande | US-05, US-09, US-13 | padrão, sem dados, desatualizado | prototypes/t03-widget-grande.html | implementada | 2026-11-03 | Lista (Mac primeiro) e gráfico. Linha cinza para leitura com mais de 30 min (aprovado em 2026-11-03). Selo de conexão no canto de baixo à direita em todos os ícones (`lb.*`, #65 e #75), sem `TransportBadge` separado; percentual em cor primária e célula `BatteryCell` mantendo a cor nos estilos translúcido e tonalizado (#64) |
| T04 | Popover da barra de menu | US-01, US-02, US-03, US-04, US-06 | padrão, vazio, carregando, erro de permissão | prototypes/t04-popover.html (atual), prototypes/t04-popover-direcoes.html (aprovado: B) | implementada | 2026-11-03 | Ícone indica o menor nível; com Histórico, Ajustes e Sair. Revisão #66, direção B aprovada pelo Lucas em 2026-11-03: anéis do médio no topo e lista embaixo (a A, linhas no estilo Central de Controle, foi descartada). Ícones próprios com o selo no símbolo, sem `TransportBadge` (#75). `glassEffect` nas seções no macOS 26+ e `.regularMaterial` antes; estados padrão, vazio, carregando, erro. Sem mudança de comportamento |
| T05 | Histórico (gráfico por aparelho) | US-09 | padrão, vazio, carregando | prototypes/t05-historico.html | implementada | 2026-10-27 | 24 h, 7 dias, 30 dias |
| T06 | Ajustes | US-07, US-08, US-10, US-11, US-14 | padrão | prototypes/t06-ajustes-sistema.html | implementada | 2026-11-03 | Revisão #67 aprovada pelo Lucas em 2026-11-03: visual dos Ajustes do Sistema (seções com cabeçalho, ícone num quadrado colorido por linha, `Form(.grouped)`), mesmas opções; versão aprovada anterior em prototypes/t06-ajustes.html. Limites, intervalo, login, largura do menu (320 a 480 pt), apagar histórico. Opção de esconder o ícone da barra de menus (aprovado em 2026-11-03, #56) |
| T07 | Guia de permissão | US-12 | padrão | prototypes/t07-permissao.html | implementada | 2026-10-27 | Leva ao painel de Privacidade |
| T08 | Notificações (baixa e carga cheia) | US-07, US-08 | baixa, crítica, cheia | prototypes/t08-notificacoes.html | implementada | 2026-10-27 | Texto e ações do sistema; sem ações (Ver aparelhos, Silenciar) |
| T09 | Widgets médio e grande com 5 ou mais aparelhos | US-05 | médio: página 1 e 2; grande: 6 aparelhos sem página, 7 com página 1 e 2; claro e escuro | prototypes/t02-t03-paginas.html | implementada | 2026-11-03 | #79, opção A escolhida pelo Lucas em 2026-11-03 nos dois tamanhos (B descartada). Botão de próxima página com indicador, `AppIntent` macOS 14+, sem interação na tela de bloqueio. Médio: 4 anéis por página. Grande: até 6 linhas numa página só, sem botão (medido no protótipo: cabem 6 linhas e o rodapé em 354 pt); a página só entra a partir do 7º aparelho, com 6 linhas por página. O gráfico de 24 h sai nessa variante. T01 fica como está. Protótipo revisado aprovado em 2026-11-03 |
| T10 | Landing page (site público, GitHub Pages) | #92 | padrão, claro e escuro, pt-BR/en/es | prototypes/landing.html | em revisão | | Download para `releases/latest`, apoio só por Pix (sem Buy Me a Coffee/Ko-fi por ora). QR Code do Pix pendente (BR Code precisa de nome e cidade do recebedor). Prints dos widgets são os do protótipo; trocar por captura do app real antes de publicar |

Estados: padrão, vazio, carregando, erro (marcar os que se aplicam e foram prototipados).
Status: rascunho, em revisão, aprovada, implementada.

## Fluxos

| Fluxo | Telas | Protótipo navegável | Status |
|---|---|---|---|
| Primeiro uso: permissão, aparelhos aparecem | T07, T04 | | rascunho |
| Consulta diária | T01, T02, T03, T04, T05 | | rascunho |
| Configurar avisos | T06, T08 | | rascunho |
