# LogiBattery

Monitor de bateria de mouse e teclado Logitech para macOS, em widget e barra de menu, inclusive os ligados por receptor (Unifying, Bolt, Lightspeed) que o macOS não mostra.

## Documentação
| Documento | Para quê |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Problema, solução, histórias e critérios de aceite |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Partes do sistema, dados, segurança, deploy |
| [docs/TESTING.md](docs/TESTING.md) | Testes por parte, comandos e definição de pronto |
| [docs/adr/](docs/adr/) | Decisões de arquitetura |
| [DESIGN.md](DESIGN.md) | Design system (tokens, componentes, regras) |
| [design/telas.md](design/telas.md) | Telas, protótipos e status de aprovação |
| [docs/API.md](docs/API.md) | Contrato da API, convenções, erros e versionamento |
| [docs/DATA.md](docs/DATA.md) | Modelo de dados, migrações, retenção e backup |

Perfil: monolito · Stack: Swift (SwiftUI, XcodeGen)

## Requisitos
- macOS 14+, Xcode 16+, XcodeGen, SwiftLint
- Permissão de Input Monitoring para o app (o macOS pede na primeira execução)

## Começando
```bash
brew install xcodegen swiftlint && xcodegen generate
cp .env.example .env   # preencher valores; nunca commitar .env
xcodebuild -scheme LogiBattery -destination 'platform=macOS' build
```

## Testes
```bash
xcodebuild test -scheme LogiBattery -destination 'platform=macOS'
swiftlint --strict
```
Detalhes em [docs/TESTING.md](docs/TESTING.md).

## Contribuindo
- Trabalho começa numa issue; branch criada pela issue (`N-slug`).
- PR com `Closes #N`, título em Conventional Commits (`tipo(escopo): resumo`).
- UI: protótipo aprovado em `design/telas.md` antes de implementar.

## Licença
Licença MIT. Veja [LICENSE](LICENSE).
