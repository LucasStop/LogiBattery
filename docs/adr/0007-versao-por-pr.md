# ADR 0007 — Bump de versão e CHANGELOG no próprio PR

- Status: aceita (plano aprovado pelo Lucas em 2026-11-13)
- Data: 2026-11-13

## Contexto
O ADR 0004 manda um PR `chore(release)` separado por versão, rodado à mão. Na prática ele não foi rodado: a main chegou a 14 commits (7 `feat`/`fix`) à frente da `v0.2.0`, o Release público (alvo do botão Baixar do site, `/releases/latest`) ficou defasado e o CHANGELOG, gerado só dos assuntos dos commits em inglês, não diz por que cada mudança existe.

## Decisão
- Cada PR `feat` sobe MINOR e cada `fix` sobe PATCH (`feat!`, `fix!` e `BREAKING CHANGE` sobem MINOR em 0.x e MAJOR depois do 1.0). `docs`, `test`, `chore`, `ci`, `refactor`, `style`, `build` e `perf` não sobem versão e não entram no CHANGELOG.
- O PR que sobe traz, no mesmo diff: `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION` (+1 por versão, contador próprio; a contagem de commits é desconhecida antes do merge) em `project.yml`, a seção nova no topo do `CHANGELOG.md` e a constante `VERSION` do `site/index.html`, que o site mostra ao lado do requisito de macOS.
- `scripts/release.sh prepare` faz o bump e escreve um rascunho do CHANGELOG; o rascunho é reescrito à mão com o porquê. É o último passo antes do merge, depois de rebasear na main: PRs paralelos que sobem a versão conflitam em `project.yml`, e o segundo rebaseia e roda `prepare` de novo.
- CHANGELOG no formato Keep a Changelog, em pt-BR (Adicionado, Alterado, Corrigido, Removido), cabeçalho `## X.Y.Z - AAAA-MM-DD`.
- O job `version-bump` do `pr-rules.yml` roda `scripts/check-version.sh` com o título do PR: `feat`/`fix` exigem versão maior que a da base no nível certo, seção no CHANGELOG e site igual; os outros tipos exigem versão igual à da base.
- Versão pública: depois do merge de um PR com bump, `scripts/release.sh publish`, no Mac do Lucas e só quando ele pedir (build assinado, zip, tag `vX.Y.Z`, GitHub Release com as notas do CHANGELOG). O CI nunca publica e o `release-check` da tag confere tag e `MARKETING_VERSION`. Resto do ADR 0004 segue valendo.

## Alternativas consideradas
- Seção "Não lançado" acumulada e release em lote: mantém o atraso que motivou este ADR.
- Publicar o Release pelo CI: o runner não tem o certificado, e o app sem assinatura do time quebra o widget (App Group).
- Versão do site lida da API do GitHub no navegador: adiciona rede a uma página estática e quebra a regra de zero requisição de terceiros.

## Consequências
- Positivas: cada versão tem entrada explicando o porquê; o número do site, o do app e o da tag não divergem sem o CI avisar.
- Negativas e riscos: o publish continua manual e pode atrasar (o `version-bump` não detecta versão mergeada e não publicada); PRs paralelos com bump conflitam.
- Impacto em testes: `scripts/test-next-version.sh` e `scripts/test-check-version.sh` no CI (`docs/TESTING.md`).
