---
tipo: indice
area: decisões arquiteturais
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-07
---

# ADRs

Este índice reúne as decisões arquiteturais que a auditoria das 18 áreas
identificou como necessárias antes de mudanças estruturais. As 12 decisões
foram **aprovadas em 2026-11-07** pelo responsável pelo projeto
(NAGCODE-Dev). O status de cada ADR está no corpo do arquivo
(`- **Status:** aceito`); o campo `status` do frontmatter é a classificação da
nota no vault, não o status da decisão.

O **ADR-0007** mantém uma pendência explícita: a escolha da licença do app
(MIT, Apache-2.0, AGPL-3.0 ou distribuição restrita) não foi decidida. A
política de fixtures e as correções mecânicas desse ADR estão aprovadas.

Em 2026-11-05 as 12 decisões foram materializadas como arquivos individuais
(listados em [[#Arquivos]]). Em 2026-11-07 a recomendação de cada uma foi
aceita; contexto, alternativas, consequências e evidências continuam nos
arquivos.

O template está em [[ADR|ADR]]. A síntese que originou a lista está em
[[../../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]].

## Como usar

1. Para decisão nova, copiar [[ADR|o template]] para `ADR-NNNN - Título.md`.
   Para as 12 abaixo, o arquivo já existe — editar o próprio arquivo.
2. Preencher contexto com evidência medida, não com opinião.
3. Listar alternativas e por que não foram escolhidas.
4. Registrar consequências, riscos e reversão.
5. Só implementar depois de status `aceito` e de tarefa de código autorizada.
   Aceitar um ADR não autoriza SQL, publicação nem mudança de código.
6. Para aceitar um ADR novo: trocar `- **Status:** proposto` por `aceito`,
   preencher a data e o responsável, substituir o **PENDENTE** da `## Decisão`
   pelo texto da decisão tomada (incluindo qual alternativa venceu) e atualizar
   a coluna Status da tabela abaixo. Para os 12 abaixo, isso já foi feito em
   2026-11-07.

## Lista de decisões

| ID | Decisão | Áreas | Urgência | Status |
|---|---|---|---|---|
| ADR-0001 | Paleta e tema: dark-only com `EmeraldColors` ou light+dark com tokens do `AGENTS.md` | 15, 16, 18 | Alta | aceito |
| ADR-0002 | Modelo de questão: objetiva/discursiva, gabarito e publicação | 2, 9, 10, 12 | Alta | aceito |
| ADR-0003 | Versionamento de conteúdo e vínculo da tentativa à versão resolvida | 2, 6, 12 | Alta | aceito |
| ADR-0004 | Persistência local: JSON/SharedPreferences vs SQLite transacional | 7, 8 | Alta | aceito |
| ADR-0005 | Distribuição Android: APK universal + splits e seleção de ABI no site | 15, 17 | Alta | aceito |
| ADR-0006 | Escopo de importação por câmera: implementar ou remover do README | 9, 13, 18 | Média | aceito |
| ADR-0007 | Licença do app e política de fixtures de terceiros | 9, 14, 17, 18 | Alta | aceito (licença pendente) |
| ADR-0008 | Hierarquia documental e versionamento do vault | 18 | Alta | aceito |
| ADR-0009 | Política de dependências, pins e cadência de atualização | 17 | Média | aceito |
| ADR-0010 | Comunidades, moderação e ciclo de vida | 11, 12 | Média | aceito |
| ADR-0011 | Tamanho de APK, modelos sob demanda e componentes nativos | 13, 17 | Média | aceito |
| ADR-0012 | Acessibilidade, tema claro/escuro e meta de contraste | 14, 16 | Média | aceito |

## Pendências e etapas futuras

Aceitar um ADR não implementa a decisão. Continuam pendentes, por decisão
explícita:

- **ADR-0007:** escolha da licença do app. É a única decisão de produto ainda
  aberta neste índice.
- **ADR-0002:** a etapa 2 (schema de discursivas) exige ADR próprio ou emenda
  com SQL autorizado.
- **ADR-0003:** a criação de `exam_versions` no servidor exige SQL autorizado.
- **ADR-0010:** comunidades dinâmicas ficam para fase posterior; a moderação
  mínima depende de SQL/RLS autorizado.
- **ADR-0011:** a escolha final da pilha de OCR depende de benchmark de
  acurácia e tempo.

## Arquivos

Criados em 2026-11-05; aceitos em 2026-11-07:

- [[ADR-0001 - Paleta e tema|ADR-0001 — Paleta e tema]]
- [[ADR-0002 - Modelo de questão, gabarito e publicação|ADR-0002 — Modelo de questão, gabarito e publicação]]
- [[ADR-0003 - Versionamento de conteúdo e vínculo da tentativa|ADR-0003 — Versionamento de conteúdo e vínculo da tentativa]]
- [[ADR-0004 - Persistência local e durabilidade|ADR-0004 — Persistência local e durabilidade]]
- [[ADR-0005 - Distribuição Android e seleção de ABI|ADR-0005 — Distribuição Android e seleção de ABI]]
- [[ADR-0006 - Escopo de importação por câmera|ADR-0006 — Escopo de importação por câmera]]
- [[ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007 — Licença do app e fixtures de terceiros]]
- [[ADR-0008 - Hierarquia documental e versionamento do vault|ADR-0008 — Hierarquia documental e versionamento do vault]]
- [[ADR-0009 - Política de dependências e pins|ADR-0009 — Política de dependências e pins]]
- [[ADR-0010 - Comunidades, moderação e ciclo de vida|ADR-0010 — Comunidades, moderação e ciclo de vida]]
- [[ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011 — Tamanho de APK, modelos e componentes nativos]]
- [[ADR-0012 - Acessibilidade, tema e contraste|ADR-0012 — Acessibilidade, tema e contraste]]

A tabela acima mantém o texto original da proposta. Dois títulos de arquivo
foram ajustados ao que a medição mostrou, e a correção está no `## Contexto`
de cada um: **0004** (provas privadas já usam escrita atômica em arquivo
atrás da porta `ExamPayloadStorage`, não “JSON/SharedPreferences”) e **0006**
(a promessa de câmera está em `AGENTS.md:302`; o `README.md:28` promete
“Imagens”).

Ordem sugerida de leitura, por dependência entre decisões: 0002 e 0003
(contrato de conteúdo) → 0004 (onde esse contrato é guardado) → 0001 e 0012
(identidade visual e meta de contraste) → 0008 (qual documento vale) →
0007, 0009, 0005, 0011 (licença, dependências, distribuição) → 0006 e 0010
(escopo de produto ainda não construído).

## Critério de aprovação

- Contexto com evidência e limites.
- Alternativas reais, incluindo “não fazer”.
- Consequências positivas e negativas.
- Validação antes da implementação.
- Reversão descrita.
- Link para a área, o código e o teste que sustentam a decisão.

## Links

- [[ADR|Template de ADR]]
- [[../../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]]
- [[../../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]]
- [[../../00 - Central/Plano Mestre|Plano Mestre]]
- [AGENTS.md](../../../AGENTS.md)
