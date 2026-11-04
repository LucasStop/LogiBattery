#!/usr/bin/env bash
# Relatório de testes a partir do .xcresult (#117): grava test-report.json ao lado do bundle e imprime o resumo em
# Markdown no stdout. Com o test-report.json da main como 2º argumento, compara regressão e evolução.
# Uso: scripts/test-report.sh build/tests.xcresult [build/main/test-report.json]
set -euo pipefail

bundle=${1:?uso: scripts/test-report.sh <tests.xcresult> [test-report.json da main]}
main_report=${2:-}

if [ ! -d "$bundle" ]; then
  echo "## Relatório de testes"
  echo
  echo "Sem \`$bundle\`: o build ou o xcodebuild falhou antes de rodar os testes."
  exit 0
fi

report="$(dirname "$bundle")/test-report.json"
result() { xcrun xcresulttool get test-results "$1" --path "$bundle"; }

jq -n --arg sha "${GITHUB_SHA:-}" \
  --argjson s "$(result summary)" --argjson t "$(result tests)" --argjson m "$(result metrics 2>/dev/null || echo '[]')" '
  def round3: (. * 1000 | round) / 1000;
  def round6: (. * 1000000 | round) / 1000000;
  {
    schema: 1,
    commit: $sha,
    total: $s.totalTestCount,
    passed: $s.passedTests,
    failed: $s.failedTests,
    skipped: $s.skippedTests,
    durationSeconds: (($s.finishTime - $s.startTime) | round3),
    tests: [$t | .. | objects | select(.nodeType == "Test Case")
            | {id: .nodeIdentifier, status: .result, seconds: ((.durationInSeconds // 0) | round3)}],
    failures: [$s.testFailures[]? | {id: .testIdentifierString, message: (.failureText | gsub("\\s+"; " "))}],
    performance: [$m[]? | .testIdentifier as $id | .testRuns[].metrics[]?
                  | {id: $id, metric: .displayName, unit: .unitOfMeasurement,
                     average: ((.measurements | add / length) | round6)}]
  }' > "$report"

if [ -n "$main_report" ] && [ -f "$main_report" ]; then main_json=$(cat "$main_report"); else main_json=null; fi

jq -r --argjson main "$main_json" '
  def n: tostring | sub("\\."; ",");
  def r1: (. * 10 | round) / 10;
  def secs: (r1 | n) + " s";
  def signed: if . > 0 then "+" + n else n end;
  def status_of($tests): $tests | map({key: .id, value: .status}) | from_entries;
  # Orçamento de desempenho = suíte `*PerformanceTests`, com asserção em contagem (docs/TESTING.md §3).
  def perf: test("PerformanceTests/");
  def ms: ((. * 100000 | round) / 100) | n;
  def list($items): $items[:30] + (if ($items | length) > 30 then ["... e mais \(($items | length) - 30)"] else [] end);

  . as $cur
  | def compare:
      status_of($main.tests) as $before | status_of($cur.tests) as $after
      | ([$after | to_entries[] | select(.value == "Failed" and $before[.key] != "Failed")
          | {id: .key, why: (if (.key | perf) then "orçamento de desempenho falhando" else "falha" end)}]
         + [$before | to_entries[] | select(.value != "Failed" and $after[.key] == null) | {id: .key, why: "sumiu"}]
         + [$before | to_entries[] | select(.value == "Passed" and $after[.key] == "Skipped")
            | {id: .key, why: "pulado"}]) as $regressions
      | (($after | keys) - ($before | keys)) as $new
      | ["", "### Regressão contra a main", ""]
        + (if ($regressions | length) == 0 then ["Nenhuma: nenhum teste da main falha, sumiu ou foi pulado."]
           else ["| Teste | O que mudou |", "|---|---|"] + [$regressions[] | "| `\(.id)` | \(.why) |"] end)
        + ["", "### Evolução contra a main", "",
           "- Testes: \($main.total) para \($cur.total) (\(($cur.total - $main.total) | signed))",
           "- Duração: \($main.durationSeconds | secs) para \($cur.durationSeconds | secs) "
             + "(\(($cur.durationSeconds - $main.durationSeconds) | r1 | signed) s; o runner varia, é só tendência)",
           "- Testes novos: \($new | length)"]
        + [list($new)[] | "  - `\(.)`"];
  [
    "## Relatório de testes", "",
    "| Total | Passou | Falhou | Pulou | Duração |", "|---:|---:|---:|---:|---:|",
    "| \($cur.total) | \($cur.passed) | \($cur.failed) | \($cur.skipped) | \($cur.durationSeconds | secs) |"
  ]
  + (if ($cur.failures | length) > 0 then ["", "### Falhas", ""] + [$cur.failures[] | "- `\(.id)`: \(.message)"] else [] end)
  + (if $main == null then ["", "Sem relatório da main para comparar (primeira execução, artifact expirado ou push fora da main)."]
     else compare end)
  + (if ($cur.performance | length) > 0
     then ["", "### Desempenho (`measure`, só tendência local: o baseline vale por máquina)", "",
           "| Teste | Métrica | Média |", "|---|---|---:|"]
          + [$cur.performance[] | "| `\(.id)` | \(.metric) | \(if .unit == "seconds" then "\(.average | ms) ms" else "\(.average | n) \(.unit)" end) |"]
     else [] end)
  | join("\n")' "$report"
