# Dados — LogiBattery

Modelo de dados, migrações e ciclo de vida da informação. Ligado a [ARCHITECTURE.md](ARCHITECTURE.md) (parte Persistência) e a [TESTING.md](TESTING.md) (testes de integração e migração).

Status: aprovada em 2026-10-27

## 1. Armazenamento
- Banco: `history.json` no container do App Group (arquivo único, escrita atômica; SwiftData fica para quando o arquivo crescer, ver `HistoryStore`) · Cache/fila: N/A · Arquivos: `snapshot.json` no App Group, lido pelo widget
- Ambientes: local e produção são o próprio Mac do usuário; teste usa diretório temporário por execução.

## 2. Entidades

| Entidade | Responsabilidade | Chave | Relações | Dado pessoal? |
|---|---|---|---|---|
| `Device` | Aparelho conhecido (nome, tipo, caminho, série em hash) | id estável derivado de série ou nome | 1 para N `Reading` | Não |
| `Reading` | Um ponto do histórico (`HistoryPoint`): porcentagem, estado de carga, momento; gravado quando o valor ou o estado muda, ou após 30 min sem mudança | (nome normalizado do aparelho, timestamp); `deviceId` muda a cada reconexão e não identifica a série | N para 1 `Device` | Não |
| `Settings` | Limites, intervalo de leitura, opções de aviso, login | única | - | Não |
| `Snapshot` | Última leitura de cada aparelho para o widget (JSON, não é tabela) | arquivo único | agrega `Device` e `Reading` | Não |

Diagrama (opcional):

```mermaid
erDiagram
  DEVICE ||--o{ READING : tem
```

## 3. Regras de integridade
- Restrições no banco (chaves, únicas, not null, checks) antes de validação só na aplicação.
- Exclusão: apagar `Device` apaga suas `Reading` (cascata); poda por retenção apaga leituras antigas.
- Concorrência: só o app host escreve; o widget só lê. Escrita do snapshot é atômica (arquivo temporário e rename).

## 4. Migrações
- Ferramenta: migração versionada do SwiftData (`VersionedSchema`). Toda migração é reversível (`down`) e testada subindo e descendo (ver TESTING.md).
- Mudança destrutiva em duas etapas: acrescentar e migrar dados, só depois remover.
- Migração em produção: roda na abertura do app; se falhar, o app preserva o arquivo antigo e abre com histórico vazio, avisando.

## 5. Dados pessoais e LGPD
- Dados pessoais coletados: nenhum. A série do aparelho é guardada só como hash. Nada sai do Mac.
- Retenção e exclusão: 90 dias por padrão (configurável); opção de apagar todo o histórico nos ajustes. Mascaramento em logs e em ambientes de teste: nunca dado real fora de produção.

## 6. Backup e recuperação
- Sem backup próprio (dado reconstruível, baixo valor); o Time Machine cobre o container se o usuário quiser. RPO/RTO: N/A.
- Restauração: N/A.

## 7. Dados de teste
- Fixtures de leituras e snapshots em `Tests/Fixtures/`. Sem série real.
