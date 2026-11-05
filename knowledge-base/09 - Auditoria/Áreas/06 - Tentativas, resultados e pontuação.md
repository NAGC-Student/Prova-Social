---
tipo: area
area: tentativas, resultados e pontuação
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 3, acoplamento: 2, clareza: 3, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 3}
fonte_codigo: [lib/features/result/result_page.dart, lib/features/result/review_page.dart, lib/domain/models/exam.dart, lib/core/review/wrong_question_practice_service.dart, test/result_review_test.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Tentativas, resultados e pontuação

## Resumo

A área entrega o ciclo essencial: encerrar a prova, persistir a tentativa,
mostrar acertos, erros, brancos, percentual, duração, desempenho por tópico,
revisão filtrável e refazer erradas — inclusive a partir do histórico local. A
base é funcional e testada. Faltam explicação por questão, discussão,
procedência na revisão, comparação de evolução, tratamento de respostas
corrompidas e uma separação melhor entre cálculo, histórico e apresentação.
Classificação: **EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/features/result/result_page.dart` (745 linhas) e
  `lib/features/result/review_page.dart` (217 linhas).
- Leitura de `lib/domain/models/exam.dart` (cálculo) e
  `lib/core/review/wrong_question_practice_service.dart` (seleção de erros).
- Leitura de `lib/core/backend/attempt_submission.dart`,
  `attempt_repository.dart` (correção vinda do servidor) e
  `attempt_sync_service.dart` (estado da entrega).
- Leitura dos testes `test/exam_result_test.dart`, `test/result_review_test.dart`,
  `test/wrong_questions_retry_test.dart` e
  `test/wrong_question_practice_service_test.dart`.
- Não foi executado fluxo autenticado real nem comparada evolução entre duas
  tentativas em produção; a análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Entrega pendente com estado de sincronização | Funcional | `result_page.dart:16-188` |
| Resultado com percentual e contagem corrigível | Funcional | `result_page.dart:210-259` |
| Tempo total, corretas e “revisar” | Parcial | `result_page.dart:261-285` |
| Refazer erradas da tentativa atual | Funcional | `result_page.dart:286-301` |
| Refazer erradas do histórico com filtros | Funcional | `result_page.dart:387-663` |
| Filtro por assunto, prova e período | Funcional | `result_page.dart:520-662` |
| Revisão com filtros todas/erradas/certas/branco/sem gabarito | Funcional | `review_page.dart:7-43, 56-88` |
| Revisão virtualizada | Funcional | `review_page.dart:98-174` |
| Procedência no resultado | Parcial | `result_page.dart:318-328` |
| Explicação por questão | Ausente | sem campo no modelo e sem widget |
| Discussão por questão | Ausente | nenhuma referência em `review_page.dart` |
| Comparação com tentativa anterior | Ausente | não há histórico comparativo no resultado |
| Exportação JSON | Funcional | `result_page.dart:353-381` |
| Correção vinda do servidor por ID | Parcial | `attempt_repository.dart:105-130` |

## O que funciona

1. **Resultado honesto sobre gabarito.** Quando não há questão corrigível, o
   percentual é “—” e o texto explica o motivo (`result_page.dart:231-250`).
2. **Separação entre erro e branco.** A tela mostra “Erradas”, “Em branco” e
   “Marcadas” em separado (`result_page.dart:308-316`), e a revisão tem filtro
   próprio para branco (`review_page.dart:40, 84`).
3. **Revisão virtualizada.** `ListView.builder` evita construir 100 ou 1.000
   questões de uma vez; o teste cobre 100 itens (`result_review_test.dart:11-69`).
4. **Filtros de revisão claros.** Os estados não dependem apenas de cor; cada
   chip tem rótulo textual e a contagem “Exibidas” confirma o filtro
   (`review_page.dart:59-87`).
5. **Prova dos erros com critério.** Só entram questões respondidas e erradas;
   brancos ficam de fora, mas continuam na revisão
   (`exam.dart:152-163`).
6. **Histórico com recorrência e recência.** O serviço prioriza questões erradas
   mais vezes e mais recentemente, distribuindo por tópico
   (`wrong_question_practice_service.dart:115-128, 187-211`).
7. **Estado de entrega sem rede.** A tela pendente mostra “salva no aparelho”,
   agenda retry e oferece “Tentar agora” (`result_page.dart:56-135`).
8. **Procedência visível.** O resultado mostra `SourceBadge`, autor, ano e link
   seguro para a fonte (`result_page.dart:318-328`).

## O que está parcial

### “Revisar” não é o número de erradas

O terceiro cartão usa `total - correct` (`result_page.dart:279-282`). Isso
inclui erradas, brancos e questões sem gabarito. O rótulo “Revisar” é aceitável,
mas o usuário pode interpretá-lo como “erradas”. Logo abaixo, “Erradas” mostra
outro número. A tela deve usar “Para revisar” ou separar erradas/brancos/sem
gabarito.

### Revisão sem explicação e sem discussão

O `AGENTS.md` §9 exige, em cada revisão, questão, resposta selecionada,
resposta correta, **explicação quando disponível**, **discussão da comunidade** e
procedência. A revisão atual mostra enunciado, mídia, resposta, gabarito e um
ícone de marcada (`review_page.dart:124-172`). Não há explicação, rubrica,
comentário ou link para discussão. O modelo também não tem esses campos (área 2).

### Respostas fora de faixa podem quebrar a revisão

`review_page.dart:111-116` acessa `question.options[selected]` e
`question.options[question.correctIndex!]` sem validar limites. Uma resposta
persistida antiga, corrompida ou de uma versão diferente pode lançar
`RangeError` e derrubar a revisão. O cálculo em `ExamResult` valida o gabarito,
mas a UI não.

### Histórico limitado e recarregado de forma implícita

`_loadHistory` usa `AttemptSyncService()` quando nenhum serviço é injetado
(`result_page.dart:413-425`). Isso acopla a tela ao serviço padrão e cria uma
segunda instância de stores. A contagem de disponibilidade é calculada com
limite 100 (`result_page.dart:416-423`); se houver mais de 100 erradas, o número
exibido subestima o total.

### Exportação JSON expõe o gabarito

“Copiar resultado JSON” serializa todas as respostas com `correct` e `isCorrect`
(`exam.dart:215-235`, `result_page.dart:353-381`). É uma ação explícita do
usuário, mas o texto não avisa que o conteúdo inclui gabarito. Se o JSON for
colado em um grupo, a chave privada vaza. O botão precisa de confirmação/aviso
ou de uma versão sem chaves.

### Correção do servidor depende de ID

`attempt_repository.dart:105-124` monta `keys` por `question_id` e aplica
`keys[question.id]`. Questão com `id` vazio nunca recebe gabarito; o resultado
fica “sem gabarito” mesmo tendo sido corrigido no servidor. Isso conecta a
falha ao modelo da área 2 e ao contrato da área 12.

## O que está ausente ou quebrado

- Explicação, rubrica e resposta esperada na revisão.
- Link para discussão da questão.
- Comparação entre tentativa atual e anterior.
- Compartilhamento do resultado.
- Aviso sobre gabarito no JSON.
- Validação de índice antes de acessar alternativas.
- Teste de resposta fora de faixa e de questão com ID vazio.
- Paginação/contagem total do histórico de erros.
- Prova dos erros com comparação de evolução sem inventar dados.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Cada revisão mostra explicação” | Não existe campo nem widget | `review_page.dart:124-172` |
| “Cada revisão mostra discussão da comunidade” | Nenhum link/comentário | `review_page.dart` |
| “Comparar evolução após nova tentativa” | Não há comparação | `result_page.dart` |
| “Refazer erradas por filtros/período/disciplina” | Existe por assunto, prova e dias, não por disciplina/banca | `result_page.dart:553-617` |
| “Resultado não inventa dados” | Percentual usa apenas corrigíveis e mostra “—” sem chave | `exam.dart:137-150` |

## Evidência de testes

- `result_review_test.dart:11-69` cobre revisão virtualizada, filtros e
  contagens.
- `result_review_test.dart:71-131` cobre filtro sem resultado e reabertura.
- `result_review_test.dart:133-206` cobre refazer apenas as erradas.
- `wrong_question_practice_service_test.dart` cobre recorrência, filtros e
  distribuição por tópico.
- `attempt_sync_service_test.dart` cobre estados de entrega e correção, mas não
  a tela de resultado com resposta inválida.
- Não há teste de explicação, discussão, comparação histórica, JSON sem chave ou
  índice fora de faixa.

## Riscos

1. **Crash na revisão.** Resposta fora de faixa derruba a tela.
2. **Vazamento de gabarito.** JSON copiado pode ser compartilhado sem aviso.
3. **Correção ausente por ID vazio.** Questão corrigida no servidor aparece sem
   gabarito.
4. **Métrica ambígua.** “Revisar” mistura erros, brancos e sem gabarito.
5. **Histórico subestimado.** Limite 100 esconde erradas antigas.
6. **Evolução não medida.** O produto promete comparar aprendizado, mas a tela
   não compara duas tentativas.

## Plano de refatoração da área

### Lote 1 — Robustez da revisão

- Validar índices de resposta e de gabarito antes de acessar a lista; mostrar
  “resposta inválida” em vez de crashar.
- Adicionar teste com índice negativo, índice igual ao tamanho e resposta de
  versão antiga.
- Critério de aceite: revisão abre com dados corrompidos e explica o problema.

### Lote 2 — Conteúdo pedagógico

- Adicionar `explanation` ao modelo e exibi-la na revisão quando existir.
- Linkar a questão à discussão (área 11) e mostrar procedência por questão.
- Critério de aceite: revisão mostra explicação/discussão quando disponíveis e
  não inventa conteúdo quando ausentes.

### Lote 3 — Histórico e evolução

- Injetar o serviço de histórico em vez de criar `AttemptSyncService()` na tela.
- Contar o total real e paginar/filtrar sem o corte de 100.
- Comparar tentativas da mesma prova/versão: acertos, erros, brancos e tópicos.
- Critério de aceite: duas tentativas geram comparação determinística; dados
  ausentes aparecem como “sem base”, nunca como zero inventado.

### Lote 4 — Exportação segura

- Oferecer “copiar sem gabarito” por padrão e “com gabarito” com confirmação.
- Critério de aceite: teste garante que a opção padrão não contém
  `correct`/`isCorrect`.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Pontuação e filtros corretos; “Revisar” ambíguo e falta conteúdo pedagógico. |
| Testes | 3 | Boa cobertura de UI e seleção; faltam dados corrompidos, ID vazio e evolução. |
| Acoplamento | 2 | Tela grande cria serviço padrão e lê store diretamente. |
| Clareza | 3 | Fluxo compreensível; rótulos e responsabilidades poderiam ser melhores. |
| Segurança | 3 | Sem segredo; JSON expõe gabarito sem aviso. |
| Robustez | 2 | Índice sem validação, histórico limitado, dependência de ID. |
| Aderência | 2 | Faltam explicação, discussão, comparação e procedência por questão. |
| Portabilidade | 3 | Layout responsivo, mas hero de 64 px e três cartões podem apertar telas pequenas. |

Classificação resultante: **EVOLUIR** — o resultado principal funciona, mas a
revisão precisa virar experiência de aprendizagem e não apenas lista de
respostas.

## Dependências

- Área 2 para explicação, tipo, versão e ID estável.
- Área 7 para histórico local e migração de respostas.
- Área 8 para correção/idempotência da submissão.
- Área 11 para discussão por questão.
- Área 12 para chaves de resposta e RPC de correção.
- Decisão de produto sobre o que significa “evolução” e como exibir sem base.

## O que não foi verificado

- Resultado real de uma tentativa autenticada no backend ativo.
- Comportamento com 1.000+ tentativas no histórico.
- Migração de respostas antigas por índice.
- Acessibilidade da revisão com leitor de tela.
- Comparação de duas tentativas da mesma prova em versões diferentes.

## Links

- [[02 - Domínio, modelos e regras|Área 2 — Domínio]]
- [[05 - Focus Mode, timer, navegação e finalização|Área 5 — Focus Mode]]
- [[07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
- [[08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]]
- [[11 - Social, discussões, comunidades e denúncia|Área 11 — Social]]
- [[../../01 - Produto/Focus Mode|Focus Mode — produto]]
- [[Mapa das Áreas|Mapa das Áreas]]
