#!/usr/bin/env bash
# Teste de check-version.sh (ADR 0007): feat/fix precisam de bump, changelog e site; os outros tipos não mexem na versão.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
fail=0

repo() { # versão-da-base -> imprime o diretório com a base em 0.1.0 marcada como `base`
  local dir; dir=$(mktemp -d)
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@t; git -C "$dir" config user.name t; git -C "$dir" config core.hooksPath /dev/null
  mkdir "$dir/site"
  printf '    MARKETING_VERSION: "%s"\n' "$1" > "$dir/project.yml"
  printf '# Changelog\n\n## %s - 2026-01-01\n' "$1" > "$dir/CHANGELOG.md"
  printf 'const VERSION="%s";\n' "$1" > "$dir/site/index.html"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "chore(repo): start"
  git -C "$dir" branch -q base
  echo "$dir"
}

bump() { # dir versão [changelog:sim|não] [site:sim|não]
  local dir=$1 v=$2
  printf '    MARKETING_VERSION: "%s"\n' "$v" > "$dir/project.yml"
  [ "${3:-sim}" = sim ] && printf '# Changelog\n\n## %s - 2026-01-02\n' "$v" > "$dir/CHANGELOG.md"
  [ "${4:-sim}" = sim ] && printf 'const VERSION="%s";\n' "$v" > "$dir/site/index.html"
  return 0
}

expect() { # nome esperado(0|1) título dir
  local name=$1 want=$2 title=$3 dir=$4 got=0
  REPO=$dir "$here/check-version.sh" base "$title" >/dev/null 2>&1 || got=1
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: esperado $want, veio $got"; fail=1; fi
  rm -rf "$dir"
}

d=$(repo 0.1.0); bump "$d" 0.2.0;            expect "feat com bump, changelog e site passa" 0 "feat(ui): x" "$d"
d=$(repo 0.1.0);                              expect "feat sem bump falha" 1 "feat(ui): x" "$d"
d=$(repo 0.1.0); bump "$d" 0.1.1;            expect "feat só com PATCH falha" 1 "feat(ui): x" "$d"
d=$(repo 0.1.0); bump "$d" 0.1.1;            expect "fix com PATCH passa" 0 "fix(core): x" "$d"
d=$(repo 0.1.0); bump "$d" 0.1.1;            expect "fix! exige MINOR" 1 "fix(core)!: x" "$d"
d=$(repo 0.1.0); bump "$d" 0.2.0 não sim;    expect "bump sem changelog falha" 1 "feat(ui): x" "$d"
d=$(repo 0.1.0); bump "$d" 0.2.0 sim não;    expect "bump sem site falha" 1 "feat(ui): x" "$d"
d=$(repo 0.2.0); bump "$d" 0.1.0;            expect "versão menor falha" 1 "feat(ui): x" "$d"
d=$(repo 0.1.0);                              expect "docs sem bump passa" 0 "docs(prd): x" "$d"
d=$(repo 0.1.0); bump "$d" 0.1.1;            expect "docs com bump falha" 1 "docs(prd): x" "$d"
d=$(repo 0.1.0);                              expect "título fora do padrão falha" 1 "algo" "$d"
exit $fail
