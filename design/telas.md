# Inventário de telas — LogiBattery

Fluxo e regras em [README.md](README.md). Tela só vai para desenvolvimento com status `aprovada`.

| ID | Tela / fluxo | História (PRD) | Estados prototipados | Protótipo | Status | Aprovada em | Notas |
|---|---|---|---|---|---|---|---|
| T01 | Widget pequeno | US-05, US-13 | padrão, sem dados, desatualizado | prototypes/t01-widget-pequeno.html | aprovada | 2026-11-03 | 4 posições em anéis 2x2, anel vazio onde falta aparelho; ícone no centro com o selo de conexão no próprio símbolo, no canto de baixo à direita (símbolos `lb.*`, aprovado em 2026-11-03, #65); sem percentual (revisado em 2026-11-03, pedido do Lucas, #55). Anel cinza para leitura com mais de 30 min. Medidas do Baterias da Apple (DESIGN.md §3.8, #63): anel de 64 pt, vão de 12, ícone de 24 pt em cor primária. #75 (em revisão): selo de conexão no canto de baixo à direita em todos os ícones, com símbolos próprios para `other` (Bluetooth e receptor) e fone no receptor, sem `TransportBadge` separado; aprovação anterior vale até o Lucas aprovar a revisão |
| T02 | Widget médio | US-05, US-13 | padrão, sem dados, desatualizado | prototypes/t02-widget-medio.html | aprovada | 2026-11-03 | Anéis numa linha 4x1 no visual do médio da Apple: ícone e percentual em cor primária, selo de conexão ao lado do percentual (revisado em 2026-11-03, pedido do Lucas, #55 e #60); mouse, teclado e fone trazem o selo no próprio símbolo (#65). Anel cinza para leitura com mais de 30 min. Medidas do Baterias da Apple (DESIGN.md §3.8, #63): 4 colunas iguais, anel de 62 pt, ícone de 24 pt, percentual de 16 pt. #75 (em revisão): selo de conexão no canto de baixo à direita em todos os ícones, com símbolos próprios para `other` (Bluetooth e receptor) e fone no receptor, sem `TransportBadge` separado; aprovação anterior vale até o Lucas aprovar a revisão |
| T03 | Widget grande | US-05, US-09 | padrão, sem dados, desatualizado | prototypes/t03-widget-grande.html | aprovada | 2026-11-03 | Lista e gráfico. Linha cinza para leitura com mais de 30 min (aprovado em 2026-11-03). #75 (em revisão): selo de conexão no canto de baixo à direita em todos os ícones, com símbolos próprios para `other` (Bluetooth e receptor) e fone no receptor, sem `TransportBadge` separado; aprovação anterior vale até o Lucas aprovar a revisão |
| T04 | Popover da barra de menu | US-01, US-02, US-03, US-04, US-06 | padrão, vazio, carregando, erro de permissão | prototypes/t04-popover.html | implementada | 2026-10-27 | Ícone indica o menor nível; com Histórico, Ajustes e Sair |
| T05 | Histórico (gráfico por aparelho) | US-09 | padrão, vazio, carregando | prototypes/t05-historico.html | implementada | 2026-10-27 | 24 h, 7 dias, 30 dias |
| T06 | Ajustes | US-07, US-08, US-10, US-11, US-14 | padrão | prototypes/t06-ajustes.html | implementada | 2026-10-27 | Limites, intervalo, login, apagar histórico. Opção de esconder o ícone da barra de menus (aprovado em 2026-11-03, #56) |
| T07 | Guia de permissão | US-12 | padrão | prototypes/t07-permissao.html | implementada | 2026-10-27 | Leva ao painel de Privacidade |
| T08 | Notificações (baixa e carga cheia) | US-07, US-08 | baixa, crítica, cheia | prototypes/t08-notificacoes.html | implementada | 2026-10-27 | Texto e ações do sistema; sem ações (Ver aparelhos, Silenciar) |

Estados: padrão, vazio, carregando, erro (marcar os que se aplicam e foram prototipados).
Status: rascunho, em revisão, aprovada, implementada.

## Fluxos

| Fluxo | Telas | Protótipo navegável | Status |
|---|---|---|---|
| Primeiro uso: permissão, aparelhos aparecem | T07, T04 | | rascunho |
| Consulta diária | T01, T02, T03, T04, T05 | | rascunho |
| Configurar avisos | T06, T08 | | rascunho |
