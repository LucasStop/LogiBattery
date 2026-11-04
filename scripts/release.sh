#!/usr/bin/env bash
# Release do LogiBattery (ADR 0004). Roda no Mac do Lucas, só quando ele pedir: o CI não tem o certificado.
#   release.sh prepare   -> na branch do PR chore(release): sobe MARKETING_VERSION, CURRENT_PROJECT_VERSION e CHANGELOG.md
#   release.sh publish   -> na main, depois do merge: build assinado, zip, tag vX.Y.Z e GitHub Release
set -euo pipefail
cd "$(dirname "$0")/.."
team=69D4S5TF8S
marketing() { sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml; }

case "${1:-}" in
prepare)
  next=$(scripts/next-version.sh)
  [ "$next" != "$(marketing)" ] || { echo "Nada pede bump desde a última tag."; exit 1; }
  section=$(scripts/next-version.sh --changelog)
  sed -i '' -E "s/^( *MARKETING_VERSION: )\".*\"/\1\"$next\"/; s/^( *CURRENT_PROJECT_VERSION: )\".*\"/\1\"$(git rev-list --count HEAD)\"/" project.yml
  { echo "# Changelog"; echo; echo "$section"; [ -f CHANGELOG.md ] && tail -n +2 CHANGELOG.md | sed '1{/^$/d;}' | sed '1i\
'; } > CHANGELOG.md.new
  mv CHANGELOG.md.new CHANGELOG.md
  echo "Preparado $next. Commit: chore(release): v$next"
  ;;
publish)
  version=$(marketing); tag="v$version"
  [ "$(git branch --show-current)" = main ] && [ -z "$(git status --porcelain)" ] || { echo "Precisa estar na main limpa."; exit 1; }
  git fetch -q --tags
  ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "Tag $tag já existe."; exit 1; }
  derived=$(mktemp -d)
  trap 'rm -rf "$derived"' EXIT
  xcodegen generate >/dev/null
  xcodebuild -scheme LogiBattery -configuration Release -derivedDataPath "$derived" \
    DEVELOPMENT_TEAM=$team "CODE_SIGN_IDENTITY=Apple Development" -allowProvisioningUpdates build >/dev/null
  app="$derived/Build/Products/Release/LogiBattery.app"
  signature=$(codesign -dv "$app" 2>&1) # sem pipe para o grep: `grep -q` fecha o pipe e o pipefail vê SIGPIPE
  grep -q "TeamIdentifier=$team" <<<"$signature" || { echo "App sem o time $team."; exit 1; }
  built=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist")
  [ "$built" = "$version" ] || { echo "App $built diverge do project.yml $version."; exit 1; }
  zip="LogiBattery-$version.zip"
  ditto -c -k --keepParent "$app" "$derived/$zip"
  notes=$(awk -v v="## $version " 'index($0, v) == 1 {on=1; next} /^## / {on=0} on' CHANGELOG.md)
  git tag "$tag" && git push -q origin "$tag"
  gh release create "$tag" "$derived/$zip" --title "LogiBattery $version" --notes "$notes"
  ;;
*) echo "Uso: release.sh prepare|publish"; exit 2 ;;
esac
