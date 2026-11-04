#!/usr/bin/env bash
# Próxima versão (ADR 0004) a partir dos Conventional Commits desde a última tag vX.Y.Z.
# Uso: next-version.sh            -> imprime a próxima versão (ou a atual, se nada pede bump)
#      next-version.sh --changelog -> imprime a seção do CHANGELOG da próxima versão
# REPO=<dir> aponta para outro repositório (testes).
set -euo pipefail
git_() { git -C "${REPO:-.}" "$@"; }

last_tag=$(git_ describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
current=${last_tag#v}
current=${current:-0.0.0}
range=${last_tag:+$last_tag..HEAD}

major=${current%%.*}; rest=${current#*.}; minor=${rest%%.*}; patch=${rest#*.}
bump=none
feats=""; fixes=""
while IFS=$'\t' read -r hash subject; do
  [ -n "$hash" ] || continue
  re='^([a-z]+)(\([a-z0-9-]+\))?(!)?: (.+)$'
  [[ $subject =~ $re ]] || continue
  type=${BASH_REMATCH[1]}; breaking=${BASH_REMATCH[3]}; text=${BASH_REMATCH[4]}
  line="- ${text} (${hash})"
  if [ -n "$breaking" ]; then bump=minor; [ "$major" -ge 1 ] && bump=major; fi
  case $type in
    feat) feats+="$line"$'\n'; [ "$bump" = major ] || bump=minor ;;
    fix) fixes+="$line"$'\n'; [ "$bump" = none ] && bump=patch ;;
  esac
done < <(git_ log --no-merges --format='%h%x09%s' $range)

case $bump in
  major) next="$((major + 1)).0.0" ;;
  minor) next="$major.$((minor + 1)).0" ;;
  patch) next="$major.$minor.$((patch + 1))" ;;
  none) next=$current ;;
esac

if [ "${1:-}" = "--changelog" ]; then
  echo "## $next - $(date +%Y-%m-%d)"
  if [ -n "$feats" ]; then printf '\n### Novidades\n\n%s' "$feats"; fi
  if [ -n "$fixes" ]; then printf '\n### Correções\n\n%s' "$fixes"; fi
else
  echo "$next"
fi
