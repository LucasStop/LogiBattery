# LogiBattery

Contexto do projeto para a CLI de IA. Regras globais em `~/.claude/CLAUDE.md` valem; aqui só o específico do repo. `CLAUDE.md` e `GEMINI.md` são symlinks para este arquivo.

## O que é
App nativo macOS (barra de menu + widget WidgetKit) que lê a bateria de mouse e teclado Logitech por HID++, via receptor e Bluetooth, com avisos e histórico. Detalhe em docs/PRD.md.
Perfil: monolito · Stack: Swift (SwiftUI, XcodeGen) (ver `.projeto.yml`)

## Documentação (ler antes de mexer)
- [docs/PRD.md](docs/PRD.md): problema, histórias e critérios de aceite
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): partes do sistema e decisões (ADR em docs/adr/)
- [docs/HIDPP.md](docs/HIDPP.md): features HID++ medidas por aparelho e o que cada uma destrava
- [docs/QCY.md](docs/QCY.md): protocolo BLE do fone QCY medido (bateria por lado, ANC, LDAC) e seus limites
- [docs/TESTING.md](docs/TESTING.md): quais testes valem para cada parte e como rodar
- [DESIGN.md](DESIGN.md): design system
- [design/telas.md](design/telas.md): inventário de telas e aprovação
- [docs/API.md](docs/API.md): contrato da API (OpenAPI), convenções de erro e versionamento
- [docs/DATA.md](docs/DATA.md): entidades, migrações, retenção e backup

## Regras de fluxo
- Mudança de comportamento atualiza PRD/ARCHITECTURE/TESTING no mesmo PR.
- Teste no nível certo conforme `docs/TESTING.md`; bug corrigido ganha teste de regressão.
- Estratégia de testes e arquitetura precisam de "aprovado em AAAA-MM-DD" (Lucas) antes da implementação.
- Perfil monólito: tela só é implementada com protótipo `aprovada` em `design/telas.md`. Sem aprovação, parar e pedir.
- Componente ou token novo entra no `DESIGN.md` antes ou junto da tela.
- Contrato e dados: endpoints em `docs/API.md` (mesmo que só a própria UI consuma), migrações reversíveis e `docs/DATA.md` atualizado.
- Versão por PR (ADR 0007): PR `feat` sobe MINOR e `fix` sobe PATCH no próprio PR (`scripts/release.sh prepare`, último passo antes do merge, depois de rebasear na main), com a entrada do `CHANGELOG.md` reescrita com o porquê; os demais tipos não mexem na versão. Depois do merge de um PR com bump, avisar que falta `scripts/release.sh publish` (build assinado, tag e GitHub Release; só quando o Lucas pedir) e vigiar o `release-check` da tag.
- Mantenha fronteiras por módulo (domínio, persistência, web) mesmo no mesmo deploy; regra de negócio não mora em controller nem em componente.

## Comandos
- Instalar: `brew install xcodegen swiftlint && xcodegen generate`
- Dev: `xcodebuild -scheme LogiBattery -destination 'platform=macOS' build` (app nativo: a regra das portas 3000/3001 não se aplica)
- Build: `xcodebuild -scheme LogiBattery -configuration Release build`
- Testes: `xcodebuild test -scheme LogiBattery -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` (sem assinar: App Group exige certificado) · E2E: `xcodebuild test -scheme LogiBatteryUITests -destination 'platform=macOS'`
- Lint/typecheck: `swiftlint --strict`
- Dump de features HID++: `swiftc -O tools/hidpp-dump/main.swift LogiBattery/Core/HIDPP/HIDPPFeatures.swift -o /tmp/hidpp-dump && /tmp/hidpp-dump` (somente leitura; `HIDPP_RECORD=<arquivo>` grava a fixture)
- Escrita HID++: `swiftc -O tools/hidpp-write/main.swift LogiBattery/Core/HIDPP/HIDPPFrame.swift LogiBattery/Core/HIDPP/HIDPPFeatures.swift LogiBattery/Core/HIDPP/HIDPPWrite.swift -o /tmp/hidpp-write && /tmp/hidpp-write --dpi 1600` (dry-run padrão; só `--apply` escreve, com leitura de confirmação)
- Sonda do fone QCY: `tools/qcyctl/run.sh --seconds 12` (somente leitura; roda num `.app` assinado ad-hoc porque o TCC aborta binário de CLI)

## Convenções
- Swift 6 + SwiftUI (AppKit/UIKit onde preciso); projeto gerado por XcodeGen (`project.yml` é a fonte, `.xcodeproj` não se edita à mão); alvo macOS 14+.
- Lógica em ViewModels/serviços testáveis, sem dependência de SwiftUI; efeitos de sistema (arquivo, processo, rede) atrás de protocolo para trocar por fake nos testes.
- Estrutura: `<App>/` (código), `<App>Tests/`, `<App>UITests/`, `project.yml`, `design/`.
- Depois de build/release, apagar `build.noindex/` e DerivedData; o app instalado fica só em `~/Applications/<App>.app`.
- Distribuição: assinatura local (uso pessoal) agora; Developer ID e notarização depois, em issue própria. Bundle id e App Group definitivos desde já.
- Só o app host acessa HID/IOKit; o widget lê `snapshot.json` do App Group (ADR 0001).
- Protocolo HID++ atrás de protocolo Swift, com fixtures de frames em `Tests/Fixtures/hidpp/`; testes não dependem de hardware.
- Alvos: `LogiBattery` (host), `LogiBatteryWidget`, `QCYBattery` (app separado do fone QCY, reusa `Core/BLE`; `--read-only` não escreve) e `QCYBatteryTests`, `LogiBatteryTests`, `LogiBatteryUITests`. Pastas: `LogiBattery/{UI,Core/{Domain,HIDPP,Storage,Permissions,System}}`.
- Strings em `Localizable.xcstrings` (pt-BR e en). Sem log com série ou nome do usuário.

## Notas do projeto
- Sem variáveis de ambiente nem rede. Hardware do Lucas: MX Master 3S no receptor Bolt `0xC548` (índice 2, HID++ 4.5) e também por Bluetooth `0xB034`; teclado G PRO X TKL no receptor Lightspeed `0xC547` (índice 1, HID++ 4.2) e também por Bluetooth `0xB382`.
- Receptores: Unifying `0xC52B`, Bolt `0xC548`, Lightspeed `0xC539`/`0xC547`.
- Features medidas em 2026-11-12 (`docs/HIDPP.md`): bateria nos dois é `0x1004` (slot 7/8); teclado tem `0x8060` ReportRate, `0x8071` RgbEffects, `0x8081` PerKeyLightingV2, `0x8040` BrightnessControl, `0x8100` OnboardProfiles, `0x40A3`; mouse tem `0x2201` DPI, `0x2110` SmartShift, `0x2121` HiResWheel, `0x1B04`, `0x1814`/`0x1815`, `0x2250`/`0x2251`. Nenhum dos dois tem `0x1000`/`0x1001`.
- Fone QCY MeloBuds Pro (`84:AC:60:E9:90:6E`, firmware 2.0.6): não é HID++; canal GATT proprietário em `A001`, advertising por company id `0x521C`, bateria por lado/estojo em `00000008` e nos bytes 5–7 do advertising. Medido em `docs/QCY.md`. O módulo `Core/BLE` lê e escreve (cena de ANC, LDAC, modo jogo) e **não está ligado à lista de aparelhos**.
- Estado: fundação e docs em rascunho. Próximos passos: aprovar protótipos (`design/telas.md`), aprovar arquitetura e testes, aprovar BACKLOG e rodar `criar-issues.sh --criar`. Escrita HID++ existe para DPI e SmartShift com `--dry-run` padrão (#137); RGB, perfil onboard e qualquer escrita real dependem de definir quem é dono do Bolt com o Options+ aberto. Ligar o QCY na interface depende de decisão de produto (bateria por lado não cabe no modelo de um número só).
