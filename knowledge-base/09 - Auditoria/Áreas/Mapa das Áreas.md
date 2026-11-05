---
tipo: area
area: plano de auditoria profunda
status: VALIDADO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Mapa das 18 áreas de auditoria

As **18 áreas foram auditadas** contra o código, os testes, o banco, o CI, o
site e a documentação no SHA `05a8fc1`. Cada nota segue o contrato do
[[_Briefing das Auditorias|briefing]], cita arquivos e linhas e separa o que foi
verificado do que não foi.

**Resultado:** 16 áreas **EVOLUIR**, 2 áreas **REFATORAR** (Domínio e Supabase)
e nenhuma **MANTER** ou **REESCREVER**. A síntese global, com achados
transversais, ordem dos lotes e ADRs necessários, está em
[[../Síntese da Refatoração|Síntese da Refatoração]].

## Placar

Ordem dos critérios: correção / testes / acoplamento / clareza / segurança /
robustez / aderência / portabilidade.

| # | Área | Classificação | Notas |
|---:|---|---|---|
| 1 | [[01 - Núcleo, inicialização, backend e atualizações\|Núcleo]] | EVOLUIR | 3/3/3/4/4/2/3/3 |
| 2 | [[02 - Domínio, modelos e regras\|Domínio]] | **REFATORAR** | 3/2/3/4/3/2/2/4 |
| 3 | [[03 - Autenticação, visitante e deep links\|Autenticação]] | EVOLUIR | 3/2/3/4/3/2/2/3 |
| 4 | [[04 - Catálogo, busca, feed, biblioteca e perfil\|Catálogo]] | EVOLUIR | 3/2/2/4/4/2/2/4 |
| 5 | [[05 - Focus Mode, timer, navegação e finalização\|Focus Mode]] | EVOLUIR | 3/3/3/4/4/3/2/3 |
| 6 | [[06 - Tentativas, resultados e pontuação\|Tentativas]] | EVOLUIR | 3/3/2/3/3/2/2/3 |
| 7 | [[07 - Persistência local, backups e provas locais\|Persistência]] | EVOLUIR | 4/4/3/4/4/3/3/3 |
| 8 | [[08 - Sincronização, offline, idempotência e conflitos\|Sincronização]] | EVOLUIR | 4/4/3/4/5/3/3/3 |
| 9 | [[09 - Importação, OCR, parser e quality gate\|Importação e OCR]] | EVOLUIR | 3/3/2/3/3/3/3/4 |
| 10 | [[10 - Publicação, pacotes, mídia e Storage\|Publicação]] | EVOLUIR | 3/2/3/4/4/3/2/4 |
| 11 | [[11 - Social, discussões, comunidades e denúncia\|Social]] | EVOLUIR | 3/2/4/4/3/2/1/4 |
| 12 | [[12 - Supabase, schema, RLS e RPCs\|Supabase]] | **REFATORAR** | 4/3/3/3/4/3/2/4 |
| 13 | [[13 - OCR Android, PaddleOCR e digitalização\|OCR Android]] | EVOLUIR | 3/2/3/3/3/2/2/3 |
| 14 | [[14 - Testes, QA e benchmark\|Testes e QA]] | EVOLUIR | 3/3/3/3/3/2/2/2 |
| 15 | [[15 - CI-CD, releases, site, Web e PWA\|CI/CD]] | EVOLUIR | 3/2/3/3/3/2/2/3 |
| 16 | [[16 - Design system e componentes\|Design system]] | EVOLUIR | 3/2/3/3/3/3/2/3 |
| 17 | [[17 - Dependências e manutenção\|Dependências]] | EVOLUIR | 3/2/3/3/2/2/2/3 |
| 18 | [[18 - Documentação e divergências código × docs\|Documentação]] | EVOLUIR | 3/2/3/2/3/2/2/4 |

## Escopo de cada área

1. Núcleo (`lib/core`: tema, inicialização, backend, atualizações).
2. Domínio (`lib/domain`: modelos e regras).
3. Autenticação, visitante e deep links.
4. Catálogo, busca, feed, biblioteca e perfil.
5. Focus Mode, timer, navegação, revisão e finalização.
6. Tentativas, resultados e pontuação.
7. Persistência local, backups e provas locais.
8. Sincronização, offline, idempotência e conflitos.
9. Importação, OCR, parser e quality gate.
10. Publicação, pacotes, mídia e Storage.
11. Social: discussões, comunidades e denúncia.
12. Supabase: schema, RLS, RPCs, migrations e idempotência.
13. `paddleocr_android`.
14. Testes e QA.
15. CI/CD, releases, site, Web/PWA.
16. Design system e componentes.
17. Dependências e manutenção.
18. Documentação e divergências código × docs.

## Como ler cada nota

- **O que faz de fato:** comportamentos observados com evidência.
- **O que está parcial:** funcionalidades incompletas, heurísticas frágeis e
  dívida relevante.
- **O que está ausente ou quebrado:** lacunas contra o `AGENTS.md`.
- **Divergências documentação × código:** tabela `afirmação | realidade |
  evidência`.
- **Evidência de testes:** o que os testes cobrem e o que não cobrem.
- **Plano de refatoração:** lotes pequenos com critério de aceite.
- **Classificação:** nota por critério, não uma impressão geral.
- **O que não foi verificado:** limite explícito da auditoria.

## Regras de evidência

- Não classificar implementação como adequada somente por nome, comentário ou
  teste isolado.
- Toda afirmação de estado cita arquivo, linha, comando ou execução.
- Separação obrigatória entre “existe no código”, “funciona em teste” e
  “validado em produto”.
- Não reproduzir conteúdo de prova, segredo ou dado pessoal nas notas.
- Não commitar, publicar, criar tag ou release sem autorização explícita.

## Links

- [[../Síntese da Refatoração|Síntese da Refatoração]]
- [[_Briefing das Auditorias|Briefing das auditorias]]
- [[../../00 - Central/Estado Atual|Estado Atual]]
- [[../../00 - Central/Plano Mestre|Plano Mestre]]
- [[../../00 - Central/Roadmap|Roadmap]]
- [[../../08 - Agentes/Progresso|Progresso]]
- [[../../05 - Qualidade/Validação Atual|Validação Atual]]
