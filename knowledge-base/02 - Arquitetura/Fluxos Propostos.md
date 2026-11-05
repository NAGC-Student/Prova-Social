---
tipo: area
area: fluxos de arquitetura
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/import/, lib/core/backend/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-05
---

# Fluxos Propostos (alvo de produto — os medidos estão em [[Fluxos Reais]])

Os diagramas abaixo resumem os fluxos-alvo do Plano Mestre e das diretrizes do
produto. As fronteiras exatas, dados transferidos e estados de falha **foram
confirmados em 2026-11-05** em [[Fluxos Reais]]; onde os dois divergirem,
[[Fluxos Reais]] descreve o código e esta nota descreve a intenção.

## Importação

```mermaid
flowchart LR
  A[Arquivo escolhido] --> B[Extração de texto e páginas]
  B --> C[Perfil/layout e ordenação]
  C --> D{Texto suficiente nesta página?}
  D -->|Não| E[OCR local seletivo]
  D -->|Sim| F[Normalização]
  E --> F
  F --> G[Parser de questões]
  G --> H[Quality gate e confiança]
  H --> I[Revisão humana]
  I --> J[Rascunho local]
  J --> K{Confirmação explícita}
  K -->|Publicar| L[Serviço de publicação]
  K -->|Não| J
```

## Tentativa e sincronização

```mermaid
flowchart LR
  A[Iniciar prova] --> B[Resposta local imediata]
  B --> C[Persistir draft]
  C --> D[Finalizar tentativa]
  D --> E[Fila idempotente por clientAttemptId]
  E -->|Sem rede| F[Manter para retry]
  F --> E
  E -->|Rede disponível| G[Enviar e reconciliar]
  G --> H[Resultado]
```

## Publicação e consumo

```mermaid
flowchart LR
  A[Conteúdo revisado] --> B[Validar procedência e permissões]
  B --> C[Separar respostas privadas]
  C --> D[Publicar metadados e conteúdo]
  D --> E[Empacotar e verificar integridade]
  E --> F[Storage / entrega]
  F --> G[Cache local]
  G --> H[Resolver offline]
```

Antes de transformar qualquer fluxo em ADR de arquitetura, verificar contratos
atuais, transições, idempotência e falhas. [[../09 - Auditoria/Áreas/Mapa das Áreas|Auditoria profunda]].
