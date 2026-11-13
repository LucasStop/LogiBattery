#!/usr/bin/env bash
# Teste de next-version.sh com repositórios git de fixture (ADR 0007): bump pelos commits de BASE..HEAD.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
fail=0

repo() { # versão-atual -> imprime o diretório; main = commit inicial
  local dir; dir=$(mktemp -d)
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@t; git -C "$dir" config user.name t; git -C "$dir" config core.hooksPath /dev/null
  printf '    MARKETING_VERSION: "%s"\n' "$1" > "$dir/project.yml"
  git -C "$dir" add project.yml
  git -C "$dir" commit -q -m "chore(repo): start"
  git -C "$dir" branch -q base
  echo "$dir"
}

check() { # nome versão-atual esperado commits...
  local name=$1 current=$2 expected=$3; shift 3
  local dir; dir=$(repo "$current")
  for message in "$@"; do git -C "$dir" commit -q --allow-empty -m "$message"; done
  local got; got=$(REPO=$dir BASE=base "$here/next-version.sh")
  if [ "$got" = "$expected" ]; then echo "ok   $name"; else echo "FAIL $name: esperado $expected, veio $got"; fail=1; fi
  rm -rf "$dir"
}

check "sem commit relevante não sobe" 0.1.0 0.1.0 "docs(prd): text" "test(core): more" "chore(ci): tweak"
check "fix sobe PATCH" 0.1.0 0.1.1 "fix(core): bug" "docs(prd): text"
check "feat sobe MINOR" 0.1.4 0.2.0 "fix(core): bug" "feat(ui): thing"
check "breaking em 0.x sobe MINOR" 0.1.0 0.2.0 "feat(core)!: contract change"
check "commit fora do padrão é ignorado" 0.1.0 0.1.0 "random message"
check "breaking depois do 1.0 sobe MAJOR" 1.2.3 2.0.0 "feat(core)!: break"

dir=$(repo 1.2.3)
git -C "$dir" commit -q --allow-empty -m "feat(core): thing"
git -C "$dir" commit -q --allow-empty -m "fix(core): bug"
changelog=$(REPO=$dir BASE=base "$here/next-version.sh" --changelog)
if grep -q "### Adicionado" <<<"$changelog" && grep -q "### Corrigido" <<<"$changelog" && grep -q "^## 1.3.0 - " <<<"$changelog"; then
  echo "ok   rascunho do changelog"; else echo "FAIL changelog: $changelog"; fail=1; fi
rm -rf "$dir"
exit $fail
