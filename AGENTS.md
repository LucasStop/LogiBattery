# LogiBattery

Contexto do projeto para a CLI de IA. Regras globais em `~/.claude/CLAUDE.md` valem; aqui só o específico do repo. `CLAUDE.md` e `GEMINI.md` são symlinks para este arquivo.

## O que é
App nativo macOS (barra de menu + widget WidgetKit) que lê a bateria de mouse e teclado Logitech por HID++, via receptor e Bluetooth, com avisos e histórico. Detalhe em docs/PRD.md.
Perfil: monolito · Stack: Swift (SwiftUI, XcodeGen) (ver `.projeto.yml`)

## Documentação (ler antes de mexer)
- [docs/PRD.md](docs/PRD.md): problema, histórias e critérios de aceite
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): partes do sistema e decisões (ADR em docs/adr/)
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
- Mantenha fronteiras por módulo (domínio, persistência, web) mesmo no mesmo deploy; regra de negócio não mora em controller nem em componente.

## Comandos
- Instalar: `brew install xcodegen swiftlint && xcodegen generate`
- Dev: `xcodebuild -scheme LogiBattery -destination 'platform=macOS' build` (app nativo: a regra das portas 3000/3001 não se aplica)
- Build: `xcodebuild -scheme LogiBattery -configuration Release build`
- Testes: `xcodebuild test -scheme LogiBattery -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` (sem assinar: App Group exige certificado) · E2E: `xcodebuild test -scheme LogiBatteryUITests -destination 'platform=macOS'`
- Lint/typecheck: `swiftlint --strict`

## Convenções
- Swift 6 + SwiftUI (AppKit/UIKit onde preciso); projeto gerado por XcodeGen (`project.yml` é a fonte, `.xcodeproj` não se edita à mão); alvo macOS 14+.
- Lógica em ViewModels/serviços testáveis, sem dependência de SwiftUI; efeitos de sistema (arquivo, processo, rede) atrás de protocolo para trocar por fake nos testes.
- Estrutura: `<App>/` (código), `<App>Tests/`, `<App>UITests/`, `project.yml`, `design/`.
- Depois de build/release, apagar `build.noindex/` e DerivedData; o app instalado fica só em `~/Applications/<App>.app`.
- Distribuição: assinatura local (uso pessoal) agora; Developer ID e notarização depois, em issue própria. Bundle id e App Group definitivos desde já.
- Só o app host acessa HID/IOKit; o widget lê `snapshot.json` do App Group (ADR 0001).
- Protocolo HID++ atrás de protocolo Swift, com fixtures de frames em `Tests/Fixtures/hidpp/`; testes não dependem de hardware.
- Alvos: `LogiBattery` (host), `LogiBatteryWidget`, `LogiBatteryTests`, `LogiBatteryUITests`. Pastas: `LogiBattery/{UI,Core/{Domain,HIDPP,Storage,Permissions,System}}`.
- Strings em `Localizable.xcstrings` (pt-BR e en). Sem log com série ou nome do usuário.

## Notas do projeto
- Sem variáveis de ambiente nem rede. Hardware do Lucas: mouse e teclado Logitech por receptor e por Bluetooth; modelos e PID do receptor saem de `ioreg -p IOUSB -l` no primeiro run.
- Receptores: Unifying `0xC52B`, Bolt `0xC548`, Lightspeed `0xC539`/`0xC547`. Features de bateria: `0x1004`, `0x1000`, `0x1001`.
- Estado: fundação e docs em rascunho. Próximos passos: aprovar protótipos (`design/telas.md`), aprovar arquitetura e testes, aprovar BACKLOG e rodar `criar-issues.sh --criar`.
