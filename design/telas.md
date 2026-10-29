# Inventário de telas — LogiBattery

Fluxo e regras em [README.md](README.md). Tela só vai para desenvolvimento com status `aprovada`.

| ID | Tela / fluxo | História (PRD) | Estados prototipados | Protótipo | Status | Aprovada em | Notas |
|---|---|---|---|---|---|---|---|
| T01 | Widget pequeno | US-05 | padrão, sem dados, desatualizado | prototypes/t01-widget-pequeno.html | implementada | 2026-10-27 | Aparelho mais crítico |
| T02 | Widget médio | US-05 | padrão, sem dados, desatualizado | prototypes/t02-widget-medio.html | implementada | 2026-10-27 | Até 3 aparelhos |
| T03 | Widget grande | US-05, US-09 | padrão, sem dados, desatualizado | prototypes/t03-widget-grande.html | aprovada | 2026-10-27 | Lista e gráfico; sem o gráfico até a US-09 |
| T04 | Popover da barra de menu | US-01, US-02, US-03, US-04, US-06 | padrão, vazio, carregando, erro de permissão | prototypes/t04-popover.html | aprovada | 2026-10-27 | Ícone indica o menor nível |
| T05 | Histórico (gráfico por aparelho) | US-09 | padrão, vazio, carregando | prototypes/t05-historico.html | aprovada | 2026-10-27 | 24 h, 7 dias, 30 dias |
| T06 | Ajustes | US-07, US-08, US-10, US-11 | padrão | prototypes/t06-ajustes.html | aprovada | 2026-10-27 | Limites, intervalo, login, apagar histórico |
| T07 | Guia de permissão | US-12 | padrão | prototypes/t07-permissao.html | aprovada | 2026-10-27 | Leva ao painel de Privacidade |
| T08 | Notificações (baixa e carga cheia) | US-07, US-08 | baixa, crítica, cheia | prototypes/t08-notificacoes.html | aprovada | 2026-10-27 | Texto e ações do sistema |

Estados: padrão, vazio, carregando, erro (marcar os que se aplicam e foram prototipados).
Status: rascunho, em revisão, aprovada, implementada.

## Fluxos

| Fluxo | Telas | Protótipo navegável | Status |
|---|---|---|---|
| Primeiro uso: permissão, aparelhos aparecem | T07, T04 | | rascunho |
| Consulta diária | T01, T02, T03, T04, T05 | | rascunho |
| Configurar avisos | T06, T08 | | rascunho |
