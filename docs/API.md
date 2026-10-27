# API — LogiBattery

Contrato e convenções da API. A fonte do contrato é o OpenAPI (N/A, sem API HTTP; o contrato é o schema do `snapshot.json` abaixo); este arquivo documenta as decisões que o schema não diz. Mudança de contrato atualiza o OpenAPI, este arquivo e os testes de contrato no mesmo PR (ver [TESTING.md](TESTING.md)).

Status: aprovada em 2026-10-27. Sem API de rede: este arquivo registra o contrato interno entre o app host e o widget.

## 1. Visão
- Consumidores: a extensão de widget, que lê o snapshot. Nenhum terceiro.
- Base URL: N/A. O canal é o arquivo `snapshot.json` no container do App Group `group.<bundle-id>.battery`.
- Estilo: arquivo compartilhado · Formato: JSON, UTF-8

## 2. Convenções
- Recursos no plural e em minúsculas: `/<recursos>/{id}`. Verbos HTTP com a semântica padrão (GET sem efeito colateral, PUT/DELETE idempotentes).
- Datas em ISO 8601 UTC; dinheiro como inteiro em centavos mais código da moeda; ids como string estável derivada do aparelho.
- Campos em camelCase, iguais em todos os endpoints.
- Paginação: N/A.
- Idempotência: `Idempotency-Key` em POST que cria recurso ou cobra dinheiro.

## 3. Erros
Formato único (RFC 9457, `application/problem+json`): `type`, `title`, `status`, `detail`, `instance`, mais `errors[]` para validação por campo. Mensagem diz a causa e o próximo passo; nunca devolve stack trace nem dado sensível.

| Status | Quando |
|---|---|
| 400 | Requisição malformada |
| 401 | Sem credencial ou credencial inválida |
| 403 | Autenticado sem permissão |
| 404 | Recurso inexistente (ou ocultado por permissão) |
| 409 | Conflito de estado |
| 422 | Validação de regra de negócio |
| 429 | Limite de taxa |
| 5xx | Falha nossa, sempre com id de correlação |

## 4. Autenticação e autorização
- Mecanismo: o App Group só é acessível por processos assinados com o mesmo team e entitlement.
- Papéis: o host escreve, o widget lê.

## 5. Versionamento e compatibilidade
- Estratégia: campo `schemaVersion` no JSON; o widget ignora versão desconhecida e mostra o último estado válido. Mudança que quebra consumidor exige versão nova.
- Compatível: campo opcional novo, endpoint novo. Quebra: remover/renomear campo, mudar tipo, apertar validação.
- Depreciação: o host e o widget são entregues juntos; campo removido só depois de duas versões.

## 6. Limites e desempenho
- Tamanho máximo do snapshot: 64 KB. Atualização do widget: a cada leitura, por `reloadAllTimelines()`.

## 7. Endpoints

| Método e rota | Papel | Descrição | Teste |
|---|---|---|---|
| `snapshot.json` (leitura) | widget | Lista de aparelhos com `id`, `name`, `kind`, `percent`, `chargeState`, `path`, `updatedAt`, mais `schemaVersion` e `generatedAt` | `SnapshotContractTests` |
| `snapshot.json` (escrita) | host | Substitui o arquivo de forma atômica após cada leitura | `SnapshotContractTests` |

## 8. Histórico de mudanças do contrato
- 2026-10-27: contrato inicial do snapshot (`schemaVersion` 1).
