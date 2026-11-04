#!/usr/bin/env bash
# Teste de next-version.sh com repositórios git de fixture (ADR 0004).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
fail=0

check() { # nome esperado commits...
  local name=$1 expected=$2; shift 2
  local dir; dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email t@t; git -C "$dir" config user.name t; git -C "$dir" config core.hooksPath /dev/null
  git -C "$dir" commit -q --allow-empty -m "chore(repo): start"
  git -C "$dir" tag v0.1.0
  for message in "$@"; do git -C "$dir" commit -q --allow-empty -m "$message"; done
  local got; got=$(REPO=$dir "$here/next-version.sh")
  if [ "$got" = "$expected" ]; then echo "ok   $name"; else echo "FAIL $name: esperado $expected, veio $got"; fail=1; fi
  rm -rf "$dir"
}

check "sem commit relevante não sobe" 0.1.0 "docs(prd): text" "test(core): more" "chore(ci): tweak"
check "fix sobe PATCH" 0.1.1 "fix(core): bug" "docs(prd): text"
check "feat sobe MINOR" 0.2.0 "fix(core): bug" "feat(ui): thing"
check "breaking em 0.x sobe MINOR" 0.2.0 "feat(core)!: contract change"
check "commit fora do padrão é ignorado" 0.1.0 "random message"

dir=$(mktemp -d)
git -C "$dir" init -q; git -C "$dir" config user.email t@t; git -C "$dir" config user.name t; git -C "$dir" config core.hooksPath /dev/null
git -C "$dir" commit -q --allow-empty -m "chore(repo): start"; git -C "$dir" tag v1.2.3
git -C "$dir" commit -q --allow-empty -m "feat(core)!: break"
got=$(REPO=$dir "$here/next-version.sh")
if [ "$got" = "2.0.0" ]; then echo "ok   breaking depois do 1.0 sobe MAJOR"; else echo "FAIL major: $got"; fail=1; fi
changelog=$(REPO=$dir "$here/next-version.sh" --changelog)
if grep -q "### Novidades" <<<"$changelog" && grep -q "^## 2.0.0 - " <<<"$changelog"; then echo "ok   changelog"; else echo "FAIL changelog"; fail=1; fi
rm -rf "$dir"
exit $fail
