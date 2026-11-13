#!/usr/bin/env bash
# Confere a regra de versão do PR (ADR 0007). Uso: check-version.sh <ref-da-base> "<título do PR>"
# feat sobe MINOR, fix sobe PATCH (feat!/fix! sobem MINOR em 0.x); os outros tipos não mexem na versão.
# Quem sobe também traz a seção no CHANGELOG.md e a mesma versão no site. REPO=<dir> aponta para outro repositório.
set -euo pipefail
root=${REPO:-.}
base=$1; title=$2
version() { sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p'; }
new=$(version < "$root/project.yml")
old=$(git -C "$root" show "$base:project.yml" | version)

re='^([a-z]+)(\([a-z0-9-]+\))?(!)?: '
[[ $title =~ $re ]] || { echo "Título fora do padrão Conventional Commits: $title"; exit 1; }
type=${BASH_REMATCH[1]}; breaking=${BASH_REMATCH[3]}

case $type in
  feat) need=minor ;;
  fix) need=patch; [ -n "$breaking" ] && need=minor ;;
  *) need=none ;;
esac

if [ "$need" = none ]; then
  [ "$new" = "$old" ] || { echo "PR '$type' não sobe versão: $old -> $new. Volte o MARKETING_VERSION para $old."; exit 1; }
  echo "ok: '$type' sem bump ($old)"
  exit 0
fi

IFS=. read -r om on op <<<"$old"; IFS=. read -r nm nn np <<<"$new"
if   [ "$nm" != "$om" ]; then level=major
elif [ "$nn" != "$on" ]; then level=minor
elif [ "$np" != "$op" ]; then level=patch
else level=none; fi
greater=$(printf '%s\n%s\n' "$old" "$new" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
rank() { case $1 in major) echo 3 ;; minor) echo 2 ;; patch) echo 1 ;; *) echo 0 ;; esac; }
if [ "$new" = "$old" ] || [ "$greater" != "$new" ] || [ "$(rank "$level")" -lt "$(rank "$need")" ]; then
  echo "PR '$type' precisa subir $need sobre $old (veio $new). Rode scripts/release.sh prepare depois de rebasear na main."
  exit 1
fi
grep -q "^## $new - " "$root/CHANGELOG.md" || { echo "CHANGELOG.md sem a seção '## $new - AAAA-MM-DD'."; exit 1; }
grep -q "const VERSION=\"$new\"" "$root/site/index.html" || { echo "site/index.html com VERSION diferente de $new."; exit 1; }
echo "ok: '$type' sobe $old -> $new"
