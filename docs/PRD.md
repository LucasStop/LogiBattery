# PRD — LogiBattery

App nativo de macOS que mostra a bateria de mouse e teclado Logitech em um widget e na barra de menu, inclusive os conectados por receptor (Unifying, Bolt, Lightspeed), que o macOS não exibe.

## Problem Statement
O macOS mostra a bateria de periféricos Bluetooth, mas não a de periféricos ligados por receptor USB (dongle). Mouse e teclado Logitech por receptor ficam sem nenhuma indicação: a bateria acaba sem aviso no meio do trabalho. O Logi Options+ resolve, mas é pesado, pede conta e não oferece widget, histórico nem aviso de carga completa. Quem tem o mesmo aparelho pareado por receptor e por Bluetooth ainda vê dois itens soltos, sem saber que são um só.

## Solution
Um app de barra de menu que fala HID++ (protocolo da Logitech) direto com o receptor e com os aparelhos Bluetooth, lê a bateria e o estado de carga, e publica o resultado para um widget WidgetKit e para um popover. O app também guarda o histórico, avisa quando a bateria está baixa e quando a carga completa, e abre sozinho no login. Aparelho visto por mais de um caminho (receptor e Bluetooth) aparece uma vez só.

## User Stories
Cada história tem critério de aceite, que vira teste (ver [TESTING.md](TESTING.md), seção Rastreabilidade).
Se a história envolve tela, ela aparece em [../design/telas.md](../design/telas.md).

| ID | História | Critério de aceite (dado / quando / então) |
|---|---|---|
| US-01 | Como usuário, quero ver a bateria dos meus mouse e teclado Logitech ligados por receptor, para saber quando recarregar | Dado um receptor Unifying, Bolt ou Lightspeed com aparelho pareado e ligado, quando o app lê o dispositivo, então aparecem nome do aparelho e porcentagem de bateria |
| US-02 | Como usuário, quero ver também os aparelhos Bluetooth, para ter tudo na mesma lista | Dado um aparelho Logitech conectado por Bluetooth, quando o app lê o dispositivo, então ele aparece com nome e porcentagem |
| US-03 | Como usuário, quero que o mesmo aparelho visto por receptor e por Bluetooth apareça uma vez, para não ter duplicata | Dado um aparelho pareado por receptor e por Bluetooth, quando ambos os caminhos respondem, então a lista mostra um único item, com a leitura do caminho ativo |
| US-04 | Como usuário, quero saber se o aparelho está carregando ou com carga completa, para não deixá-lo na tomada sem necessidade | Dado um aparelho que reporta estado de carga, quando ele está no carregador, então o estado aparece como carregando ou cheio |
| US-05 | Como usuário, quero um widget com as baterias, para ver de relance na Mesa ou Central de Notificações | Dado ao menos um aparelho lido, quando o widget é exibido, então mostra nome, porcentagem e estado de cada aparelho nos tamanhos pequeno, médio e grande |
| US-06 | Como usuário, quero um ícone na barra de menu com popover, para consultar sem abrir janela | Dado o app rodando, quando clico no ícone, então o popover lista os aparelhos, e o ícone indica o menor nível de bateria |
| US-07 | Como usuário, quero aviso de bateria baixa, para recarregar antes de acabar | Dado um limite configurado (padrão 20% e 10%), quando a bateria de um aparelho cai abaixo dele sem estar carregando, então chega uma notificação uma única vez até ele recarregar acima do limite |
| US-08 | Como usuário, quero aviso de carga completa, para tirar o aparelho da tomada | Dado um aparelho carregando, quando ele atinge o estado cheio, então chega uma notificação uma única vez por ciclo de carga |
| US-09 | Como usuário, quero o histórico da bateria em gráfico, para entender a duração e o padrão de uso | Dado leituras guardadas, quando abro o gráfico de um aparelho, então vejo a porcentagem ao longo do tempo (24 h, 7 dias, 30 dias) |
| US-10 | Como usuário, quero que o app abra no login, para não precisar iniciar à mão | Dado a opção ligada nos ajustes, quando faço login no Mac, então o app inicia sozinho na barra de menu |
| US-11 | Como usuário, quero ajustar limites e opções, para adequar os avisos à minha rotina | Dado a tela de ajustes, quando altero limites, intervalo de leitura ou opções de aviso, então a mudança vale na próxima leitura e persiste após reiniciar |
| US-12 | Como usuário, quero ser guiado quando falta permissão, para destravar a leitura sem adivinhar | Dado que o macOS negou Input Monitoring, quando abro o app, então vejo a explicação e um botão que leva ao painel de Privacidade correto |

## Implementation Decisions
- Plataforma e stack: macOS 14+, Swift, SwiftUI, WidgetKit, Swift Charts, `UserNotifications`, `SMAppService`; projeto gerado por XcodeGen.
- Partes do sistema: ver [ARCHITECTURE.md](ARCHITECTURE.md).
- Leitura direta por HID++ (`IOHIDManager`, vendor `0x046D`), sem depender do Logi Options+ nem de driver.
- Duas partes obrigatórias: app host (único que acessa o hardware) e extensão de widget (só lê o snapshot). WidgetKit não acessa IOKit.
- Compartilhamento por App Group: snapshot JSON e histórico.
- Aparelho identificado por nome e número de série HID++; mesmo aparelho em dois caminhos vira um item.
- Uso próprio agora (assinatura local); distribuição futura. Bundle id e App Group definitivos desde o começo; notarização entra em issue posterior.

## Design Decisions
- Design system: [../DESIGN.md](../DESIGN.md). Telas e aprovação: [../design/telas.md](../design/telas.md).
- Interface nativa macOS, acompanha tema claro e escuro do sistema.
- Idiomas: português do Brasil e inglês (strings localizadas desde o início, pensando na distribuição).
- Widget em três tamanhos (pequeno, médio, grande); o grande inclui o gráfico de histórico.

## Testing Decisions
- Estratégia e matriz por parte: [TESTING.md](TESTING.md).
- Bom teste aqui roda sem hardware: o protocolo HID++ fica atrás de um protocolo Swift e os testes usam frames gravados e fakes.
- Núcleo que merece teste pesado: parser HID++ (frames, features, conversão de voltagem em porcentagem), deduplicação de aparelhos e regra de aviso (limite, anti-repetição, ciclo de carga).
- Hardware real só em smoke manual (receptor e Bluetooth).

## Out of Scope
- Controlar o aparelho (DPI, botões, teclas, iluminação, perfis). É um monitor, não um substituto do Logi Options+.
- Periféricos de outras marcas.
- Windows, Linux, iOS.
- Conta, nuvem, sincronização ou telemetria.
- Atualização de firmware.

## Further Notes
- Os modelos exatos e o PID do receptor do Lucas são descobertos no primeiro run (`ioreg -p IOUSB -l`).
- Aparelhos antigos usam HID++ 1.0 e ficam fora do MVP se não houver hardware para testar.
- Licença MIT; repositório público.
