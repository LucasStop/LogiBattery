# ADR 0008 — QCYBattery e protocolo do QCY em repositórios próprios

- Status: aceita (Lucas escolheu repo próprio e pacote compartilhado em 2026-11-25)
- Data: 2026-11-25

## Contexto
O app QCYBattery (ADR 0005, #135) e o protocolo do fone (`Core/BLE`) moravam neste repo: um `project.yml`, uma versão, um CHANGELOG, um `release.sh` e um CI para dois apps. Pelo ADR 0007, um `feat` só na janela do fone subia a versão do LogiBattery e vice-versa. O Lucas quer evoluir cada app separadamente. O LogiBattery continua lendo L/R do fone (ADR 0006).

## Decisão
- Protocolo (`QCYAdvertisement`, `QCYClient`, `QCYPacket`, `QCYState`, fixtures, `tools/qcyctl`, `docs/QCY.md`) vira o pacote SwiftPM [QCYKit](https://github.com/LucasStop/QCYKit), com tag semver. Repo próprio porque pacote remoto exige `Package.swift` na raiz.
- App de janela vira [QCYBattery](https://github.com/LucasStop/QCYBattery), com versão, CHANGELOG e release próprios (mesma regra do ADR 0007), começando em 0.1.0. Bundle id mantido.
- O LogiBattery depende do QCYKit (`from: 0.1.0`) e mantém só os adaptadores para o domínio dele: `QCYSides` e `QCYLiveReader` (`LogiBattery/Core/BLE`). Nada de escrita no fone daqui.
- Histórico dos arquivos movidos preservado com `git filter-repo` nos dois repos novos.

## Alternativas consideradas
- Mesmo repo com versão e tag por app: menos repos, mas CI, ruleset e CHANGELOG continuariam misturados.
- Copiar `Core/BLE` nos dois repos: sem pacote, mas protocolo duplicado e correção feita duas vezes.
- Tirar o QCY do LogiBattery: o popover voltaria ao "—" do macOS (ADR 0006).

## Consequências
- Positivas: cada app versiona e publica no seu ritmo; o protocolo tem uma fonte só, testada no próprio repo.
- Negativas: três repos para manter; mudança de protocolo que o LogiBattery precisa vira PR no QCYKit, tag e bump de `from:` aqui. Build do LogiBattery passa a baixar o pacote do GitHub.
- Testes: `QCYProtocolTests` e as fixtures do QCY moram no QCYKit; aqui ficam `QCYSidesTests` (com os bytes do advertising inline) e os testes de lista e ciclo de vida.
