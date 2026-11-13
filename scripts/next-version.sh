#!/usr/bin/env bash
# Próxima versão (ADR 0007) a partir dos Conventional Commits do PR: os de BASE..HEAD, sobre o MARKETING_VERSION atual.
# Uso: next-version.sh            -> imprime a próxima versão (ou a atual, se nada pede bump)
#      next-version.sh --changelog -> imprime o rascunho da seção do CHANGELOG (reescrever com o porquê antes do PR)
# REPO=<dir> aponta para outro repositório (testes); BASE=<ref> troca a base (padrão origin/main).
set -euo pipefail
git_() { git -C "${REPO:-.}" "$@"; }

current=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' "${REPO:-.}/project.yml")
range="${BASE:-origin/main}..HEAD"

major=${current%%.*}; rest=${current#*.}; minor=${rest%%.*}; patch=${rest#*.}
bump=none
added=""; fixed=""
while IFS=$'\t' read -r hash subject; do
  [ -n "$hash" ] || continue
  re='^([a-z]+)(\([a-z0-9-]+\))?(!)?: (.+)$'
  [[ $subject =~ $re ]] || continue
  type=${BASH_REMATCH[1]}; breaking=${BASH_REMATCH[3]}; text=${BASH_REMATCH[4]}
  line="- ${text}"
  if [ -n "$breaking" ]; then bump=minor; [ "$major" -ge 1 ] && bump=major; fi
  case $type in
    feat) added+="$line"$'\n'; [ "$bump" = major ] || bump=minor ;;
    fix) fixed+="$line"$'\n'; [ "$bump" = none ] && bump=patch ;;
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
  if [ -n "$added" ]; then printf '\n### Adicionado\n\n%s' "$added"; fi
  if [ -n "$fixed" ]; then printf '\n### Corrigido\n\n%s' "$fixed"; fi
else
  echo "$next"
fi
