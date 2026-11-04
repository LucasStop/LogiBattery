# ADR 0004 — Versionamento SemVer e release por script

- Status: aceita (plano aprovado pelo Lucas em 2026-11-04)
- Data: 2026-11-04

## Contexto
Existe o release `v0.1.0`, com o zip anexado à mão. `MARKETING_VERSION` está em `0.1.0` e `CURRENT_PROJECT_VERSION` nunca saiu de `1`, apesar de mais de 150 commits. Não há CHANGELOG, regra de bump nem conferência entre tag, `project.yml` e o app instalado (#123).

## Decisão
- SemVer `MAJOR.MINOR.PATCH`, em 0.x até a distribuição com Developer ID. `feat` sobe o MINOR, `fix` sobe o PATCH; `feat!`, `fix!` ou `BREAKING CHANGE` sobem o MINOR em 0.x e o MAJOR depois do 1.0. Outros tipos (`docs`, `test`, `chore`, `ci`, `refactor`) não sobem a versão sozinhos.
- Fonte única da versão: `MARKETING_VERSION` no `project.yml`, lida pelo app e pelo widget. `CURRENT_PROJECT_VERSION` é a contagem de commits da main (`git rev-list --count main`) e só cresce.
- O bump é um PR `chore(release): vX.Y.Z` que muda só `project.yml` e `CHANGELOG.md`. A próxima versão sai dos Conventional Commits desde a última tag (`scripts/next-version.sh`); o `CHANGELOG.md` agrupa por tipo, com o hash de cada commit.
- Depois do merge, `scripts/release.sh` builda assinado (time `69D4S5TF8S`), gera `LogiBattery-X.Y.Z.zip`, cria a tag `vX.Y.Z` e o GitHub Release, e confere `TeamIdentifier`. Roda só quando o Lucas pedir; o CI nunca cria release (o runner não tem o certificado).
- O CI falha se a tag não bater com o `MARKETING_VERSION`.

## Alternativas consideradas
- Release totalmente automático pelo CI: precisa do certificado no runner e merge sem o Lucas, contra a regra de não mergear por iniciativa própria.
- Versão só na tag: o app instalado não saberia dizer a própria versão.
- Notarização agora: depende de Developer ID, issue #24.

## Consequências
- Positivas: versão previsível, CHANGELOG sem esforço, app e tag sempre conferidos.
- Negativas e riscos: o release depende do Mac do Lucas. Commit mal tipado gera bump errado; o check `conventions` do CI já exige o padrão.
- Impacto em testes: `next-version.sh` testado com repo git de fixture (issue seguinte); o exploratório de 30 min de TESTING §3 roda antes de cada release.
