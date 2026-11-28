# ADR 0009 — Helper privilegiado (`SMAppService.daemon`) e saída do App Sandbox no host

- Status: aceita (Lucas aprovou o plano em 2026-11-28)
- Data: 2026-11-28

## Contexto
Para substituir o ícone nativo de bateria do macOS por completo, o popover do LogiBattery precisa:
1. Exibir fonte de energia e estado detalhado da bateria do Mac (`IOPowerSources`),
2. Ler e trocar o **Modo de Energia** (`Automatic`, `Low Power`, `High Power` — `pmset powermode 0|1|2`),
3. Listar itens em **Usando energia significativa** (brilho da tela e apps do usuário com alto consumo de CPU/wakeups via `proc_pid_rusage`),
4. Abrir **Ajustes de Bateria...** no painel do sistema.

No macOS, alterar `pmset powermode` exige privilégios de administrador (`root`), e ler `proc_pid_rusage` de outros processos do próprio usuário falha com `EPERM` dentro do App Sandbox. Até então o app host (`LogiBattery`) rodava com `com.apple.security.app-sandbox = true`, mesmo sendo distribuído fora da Mac App Store (GitHub Releases, assinatura local / Developer ID futuro).

## Decisão
- **Desligar o App Sandbox no app host (`LogiBattery`)**: `LogiBattery/LogiBattery.entitlements` remove `com.apple.security.app-sandbox` e mantém o App Group (`$(TeamIdentifierPrefix)com.lucasstop.LogiBattery`).
- **Manter o widget (`LogiBatteryWidget`) sandboxed**: a extensão WidgetKit continua com `com.apple.security.app-sandbox = true` e lendo `snapshot.json` pelo mesmo App Group (ADR 0001 intacta).
- **Helper privilegiado mínimo (`LogiBatteryPowerHelper`) via `SMAppService.daemon`**:
  - Executável Swift embutido em `Contents/Library/HelperTools/LogiBatteryPowerHelper` com manifesto em `Contents/Library/LaunchDaemons/com.lucasstop.LogiBattery.power-helper.plist`.
  - O usuário aprova uma única vez em Ajustes do Sistema > Geral > Itens de Início e Extensões; depois disso o daemon executa sob demanda via MachService XPC sem pedir senha.
  - **Superfície mínima de segurança**: o serviço XPC expõe apenas `setPowerMode(_ mode: Int, scope: String)` com allowlist fechada (`mode` em `0...2`, `scope` em `["-c", "-b"]`) e executa `/usr/bin/pmset` por caminho absoluto. O listener valida a assinatura do cliente (`SecCodeCopySigningInformation` com `bundleIdentifier == com.lucasstop.LogiBattery` e o mesmo `TeamIdentifier` quando assinado com time).
- **Amostragem de energia sob demanda**: `ProcessEnergySampler` e `DisplayBrightnessReader` só rodam enquanto o popover está aberto, preservando a meta de CPU ociosa abaixo de 1%.

## Alternativas consideradas
- **Prompt de administrador a cada troca (`osascript ... with administrator privileges`)**: evita embutir daemon, mas pede Touch ID ou senha toda vez que o usuário troca o modo de energia.
- **Somente leitura mantendo App Sandbox**: preserva o sandbox no host, mas não permite trocar o Modo de Energia nem listar apps consumindo energia significativa, ficando aquém do ícone nativo do macOS.
- **API privada `powerd` do ControlCenter**: exige entitlements privados da Apple (`com.apple.private.iokit.powermanagement`), indisponíveis fora da Apple.

## Consequências
- Positivas: troca instantânea de Modo de Energia sem senha após aprovação única; lista real de apps em "Usando energia significativa" sem precisar de `root` para leitura de processos; o widget permanece isolado.
- Negativas: o app host não pode ir para a Mac App Store enquanto estiver sem sandbox (compatível com a distribuição atual via GitHub Releases); o fluxo de aprovação do daemon em Ajustes do Sistema precisa de orientação clara na UI e validação manual em build assinado.
- Testes: parsers de `IOPowerSources` e `pmset`, lógica de troca de modo, fluxo de aprovação pendente e ranking de `ProcessEnergySampler` são testados com fakes/fixtures em `MacPowerParserTests` e `MacPowerViewModelTests`, sem depender de `root` nem de hardware.
