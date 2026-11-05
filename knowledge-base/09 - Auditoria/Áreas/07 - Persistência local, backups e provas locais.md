---
tipo: area
area: persistência local, backups e provas locais
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 4, testes: 4, acoplamento: 3, clareza: 4, seguranca: 4, robustez: 3, aderencia: 3, portabilidade: 3}
fonte_codigo: [lib/core/backend/attempt_draft_store.dart, lib/core/backend/local_exam_store.dart, lib/core/backend/local_exam_payload_store_io.dart, lib/core/backend/content_package_service.dart, lib/core/backend/attempt_sync_service.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Persistência local, backups e provas locais

## Resumo

A persistência local é uma das partes mais bem construídas do aplicativo. Provas
locais usam arquivo com gravação atômica, backup da versão anterior, compressão
gzip com SHA-256, migração do formato antigo e escrita serializada. Rascunhos de
tentativa são gravados em fila, com estado “salvando/salvo/falha”, retry e
recuperação da última versão. A fila de sincronização é idempotente e sobrevive a
reinício. As lacunas estão no que o usuário **não** consegue fazer: não há backup
restaurável de toda a biblioteca nem dos resultados, o backup `.bak` é automático
mas invisível, a fila e o rascunho não têm backup próprio, e o formato web depende
de armazenamento com quota. Também há duplicação de conteúdo entre stores e o
hash de tentativa invalida respostas quando só o gabarito muda. Classificação:
**EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/core/backend/attempt_draft_store.dart` (155 linhas),
  `local_exam_store.dart` (419), `local_exam_payload_store_io.dart` (66),
  `local_exam_payload_store_stub.dart` (16), `local_exam_payload_store.dart` (10)
  e `content_package_service.dart` (48).
- Leitura integral de `lib/core/backend/attempt_sync_service.dart` (578 linhas)
  para a fila, o formato persistido e a idempotência.
- Leitura de `lib/features/publish/publish_page.dart` (exportação/importação de
  JSON) e do aviso da biblioteca em `lib/features/home/home_page.dart:1501`.
- Leitura dos testes `test/attempt_draft_store_test.dart`,
  `test/ux/local_exam_test.dart` e `test/attempt_sync_service_test.dart`.
- Não foi testado armazenamento real em Android/iOS/Web, quota de
  `localStorage`, restauração de backup em aparelho nem migração de instalações
  antigas. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Prova local em arquivo próprio | Funcional | `local_exam_payload_store_io.dart:9-29` |
| Gravação atômica com `.tmp` e rename | Funcional | `local_exam_payload_store_io.dart:32-58` |
| Backup da versão anterior | Funcional | `local_exam_payload_store_io.dart:8, 39-51` |
| Compressão gzip com prefixo e SHA-256 | Funcional | `local_exam_store.dart:240-268`; `content_package_service.dart:16-30` |
| Migração do formato em `SharedPreferences` | Funcional | `local_exam_store.dart:192-211` |
| Leitura com fallback para backup | Funcional | `local_exam_store.dart:182-236` |
| Escrita serializada | Funcional | `local_exam_store.dart:287-307` |
| Validação de 500 questões e 100 alternativas | Funcional | `local_exam_store.dart:76-93` |
| Hash de tentativa por conteúdo | Funcional | `local_exam_store.dart:117-120` |
| Rascunho com fila e estado observável | Funcional | `attempt_draft_store.dart:59-125` |
| Retry do rascunho após falha | Funcional | `attempt_draft_store.dart:110-125` |
| Fila de entrega idempotente | Funcional | `attempt_sync_service.dart:144-195` |
| Backoff e estados de sincronização | Funcional | `attempt_sync_service.dart:375-419` |
| Exportar prova local em JSON | Funcional | `publish_page.dart:1273-1308` |
| Importar JSON de prova local | Funcional | `publish_page.dart:140-170` |
| Backup restaurável da biblioteca | Ausente | só o `.bak` automático, sem UI |
| Backup de rascunhos e resultados | Ausente | tudo em `SharedPreferences` |
| Limite de tamanho na leitura comprimida | Ausente | `local_exam_store.dart:249` chama `open(bytes)` sem limite |
| Limpeza automática de resultados antigos | Ausente | `completed()` cresce sem poda |
| Criptografia em repouso | Ausente | JSON/gzip em claro no sandbox do app |

## O que funciona

1. **Gravação atômica de verdade.** O payload é escrito em `.tmp` com `flush`,
   depois renomeado sobre o arquivo principal; o arquivo anterior vira `.bak`
   antes da troca (`local_exam_payload_store_io.dart:32-58`). Isso evita deixar a
   biblioteca pela metade em queda de energia.
2. **Backup automático e recuperação.** `load()` tenta o principal e, se a
   decodificação falhar, tenta o backup (`local_exam_store.dart:182-236`). O
   teste força corrupção no principal e recupera “Primeira”
   (`test/ux/local_exam_test.dart:219-231`).
3. **Integridade explícita.** O pacote comprimido tem prefixo `PSGZ1|`, SHA-256
   em hexadecimal e verificação antes de abrir (`local_exam_store.dart:240-250`).
   O teste corrompe o final do payload e espera `FormatException`
   (`test/ux/local_exam_test.dart:148-168`).
4. **Compressão só quando compensa.** O store compara o tamanho comprimido com o
   JSON puro e guarda o menor (`local_exam_store.dart:262-269`). Provas grandes e
   repetitivas ficam bem menores.
5. **Migração sem perda.** O payload legado em `SharedPreferences` é lido,
   convertido e só removido depois de a gravação estruturada dar certo; se a
   migração falhar, o legado é preservado (`local_exam_store.dart:192-211`).
6. **Escrita concorrente serializada.** `_serialize` mantém uma fila estática e
   captura um snapshot antes de enfileirar, então uma edição em andamento não
   altera a gravação já iniciada (`local_exam_store.dart:271-307`). O teste salva
   duas versões ao mesmo tempo e termina com a segunda
   (`test/ux/local_exam_test.dart:232-245`).
7. **Rascunho com retry real.** Cada resposta entra numa fila; falha mantém a
   última versão em memória e `flush()` tenta de novo até a revisão salva
   alcançar a atual (`attempt_draft_store.dart:74-125`). Os testes cobrem ordem,
   entrada durante o flush, falha e retry (`test/attempt_draft_store_test.dart`).
8. **Fila de entrega idempotente.** O mesmo `clientAttemptId` não duplica item;
   uma entrega já concluída é devolvida do cache; um ID reutilizado com conteúdo
   diferente é rejeitado (`attempt_sync_service.dart:144-195, 326-404`). O teste
   cobre duplicidade, reinício e reenvio.
9. **Proteção contra remoção durante tentativa.** `removeDownloaded` exige que o
   ID não esteja entre as tentativas ativas e lança
   `ActiveAttemptDownloadException` (`local_exam_store.dart:309-331`). O teste
   cobre essa proteção (`test/ux/local_exam_test.dart:101-147`).
10. **Exportação/importação de prova individual.** O editor salva JSON legível
    com `FilePicker` e o importador aceita até 4 MB, revalida a estrutura e
    atribui um ID local novo (`publish_page.dart:140-170, 1273-1308`).

## O que está parcial

### Backup existe, mas não é restaurável pelo usuário

O `.bak` é automático e só é usado quando o principal falha na decodificação.
Não há:

- botão “Exportar biblioteca” ou “Fazer backup” na Biblioteca;
- botão “Restaurar backup” escolhendo um arquivo;
- exportação conjunta de provas, rascunhos, tentativas e resultados;
- indicação de quando o backup foi feito.

O único export é por prova, dentro do editor (`publish_page.dart:1273-1308`). A
biblioteca até avisa “Exporte uma cópia antes de limpar dados ou desinstalar”
(`home_page.dart:1501`), mas não oferece a ação ali. O usuário precisa abrir cada
prova individualmente para salvar. Rascunhos e resultados não têm export algum.

### Fila e rascunho sem backup nem validação de corrupção

Rascunhos e fila de sincronização vivem em `SharedPreferences`
(`attempt_draft_store.dart:38-57`; `attempt_sync_service.dart:57-74`). Se o
JSON do rascunho corromper, `load()` lança e o QuizPage mostra “Não foi possível
restaurar a tentativa” (`quiz_page.dart:298-321`) — as respostas continuam
preservadas, mas não há tentativa de ler uma versão anterior. Se a fila
corromper, `_read()` lança antes de qualquer fallback
(`attempt_sync_service.dart:91-97`), e entregas pendentes podem ficar
inacessíveis. Não há cópia `.bak` para nenhum dos dois.

### Sem limite de tamanho na leitura do pacote local

`LocalExamStore._decode` chama `_packages.open(bytes)` sem
`maxUncompressedBytes` (`local_exam_store.dart:249`), embora
`ContentPackageService.open` aceite esse limite
(`content_package_service.dart:31-48`). O caminho de importação limita o JSON a
4 MB, mas o pacote local é gerado pelo próprio app; ainda assim, um payload
grande ou um bug de compressão pode descompactar sem teto. O teste de corrupção
não cobre bomba de descompressão.

### Conteúdo duplicado entre stores

Uma única tentativa local pode guardar o mesmo conteúdo várias vezes:

- `LocalExam` na biblioteca (`local_exam_store.dart:17-48`);
- `Exam` iniciado em `started` (`attempt_sync_service.dart:102-117`);
- rascunho com respostas (`attempt_draft_store.dart:6-28`);
- submissão pendente com o `Exam` inteiro (`attempt_sync_service.dart:460-515`);
- resultado concluído com o `Exam` inteiro (`attempt_sync_service.dart:556-578`).

Para uma prova de 90 questões com imagens, isso multiplica o uso de disco e o
tempo de serialização. Não há poda de `completed`, nem limite de resultados
guardados, nem medição de uso total.

### Hash de tentativa invalida respostas quando só o gabarito muda

`attemptExamId` é o SHA-256 de `statement`, `options` e `correctIndex`
(`local_exam_store.dart:117-120`). A intenção é boa: mudar alternativas não pode
reaproveitar respostas antigas. Mas incluir `correctIndex` faz uma simples
correção de gabarito invalidar a tentativa em andamento, mesmo que enunciado e
alternativas sejam idênticos. O usuário perde a retomada por uma correção
editorial. O hash deveria cobrir o conteúdo que o usuário viu, não a chave.

### Web depende de quota de `SharedPreferences`

No Web, `LocalExamPayloadStore` é o stub e sempre retorna `false`
(`local_exam_payload_store_stub.dart:5-15`); o store cai para
`SharedPreferences` (`local_exam_store.dart:392-405`), que no navegador é
`localStorage`. O payload comprimido é base64, o que aumenta ~33%, e a fila de
entregas e os rascunhos também competem pelo mesmo espaço. Não há medição,
aviso de quota, compressão da fila nem estratégia de IndexedDB. Em provas
grandes, o Web pode falhar de forma difícil de diagnosticar.

### Sem criptografia em repouso

Provas privadas, gabaritos, respostas e resultados ficam em JSON/gzip em claro
no diretório de suporte do app (ou em `localStorage`). O sandbox do sistema
protege contra outros apps, mas não contra backup do aparelho, root ou acesso
físico. O produto chama essas provas de “privadas neste aparelho”; a promessa é
de visibilidade local, não de confidencialidade forte. Isso precisa estar
documentado como decisão, não parecer criptografia que não existe.

### Exportação individual limitada ao editor

O JSON exportado é o `LocalExam`, não um pacote versionado de biblioteca. Ele
não inclui tentativas, resultados, coleções (que não existem) nem metadados de
backup. Importar um JSON sempre cria um ID novo
(`publish_page.dart:148-153`), o que é seguro para duplicidade, mas impede
restaurar exatamente a mesma prova no mesmo aparelho. Não há verificação de
`schemaVersion` no JSON importado.

## O que está ausente ou quebrado

- Backup/restauração da biblioteca inteira pela UI.
- Backup/restauração de rascunhos, fila e resultados.
- Exportação de histórico e de tentativas.
- Limite de descompressão no store local.
- Poda/limite de resultados concluídos.
- Medição de uso e aviso de quota no Web.
- Criptografia ou decisão explícita de não ter.
- Backup automático para a nuvem ou para arquivo escolhido pelo usuário.
- Validação de `schemaVersion` no JSON importado.
- Teste de quota, corrupção de fila e bomba de descompressão.
- Teste de restauração de backup em instalação nova.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Provas iniciadas disponíveis offline quando baixadas” | Sim; conteúdo e imagens ficam no payload local | `local_exam_store.dart:122-160` |
| “Respostas salvas localmente a cada alteração” | Sim, com fila e status | `attempt_draft_store.dart:104-108` |
| “Entrega/finalização tolera falha de rede” | Sim; grava antes e usa fila | `attempt_sync_service.dart:291-404` |
| “Backup” | Só `.bak` automático, sem UI de restauração | `local_exam_payload_store_io.dart:8` |
| “Exporte uma cópia antes de desinstalar” | Exportação existe por prova, não na biblioteca | `publish_page.dart:1273`; `home_page.dart:1501` |
| “Privadas neste aparelho” | Sem criptografia; sandbox do app | `local_exam_store.dart:16` |
| “Conteúdo compactado com hash” | Sim, mas leitura sem teto de descompressão | `local_exam_store.dart:249` |
| “Sincronização confiável” | Fila forte; corrupção da fila sem recuperação | `attempt_sync_service.dart:91-97` |

## Evidência de testes

- `test/attempt_draft_store_test.dart` cobre ordem de gravação, flush durante
  nova alteração, falha/retry, leitura do formato v1 e `clientAttemptId` estável.
- `test/ux/local_exam_test.dart:62-71` cobre invalidação por mudança de
  alternativas; `:73-100` cobre persistência de metadados e intenção de
  publicação; `:101-147` proteção de download ativo; `:148-168` compressão e
  integridade; `:170-218` cursor e versões alternativas; `:219-231` migração;
  `:232-245` escrita concorrente e recuperação de corrupção; `:247-268` prova
  grande; `:269-299` falha de gravação e recuperação da versão válida.
- `test/attempt_sync_service_test.dart` cobre idempotência, duplicidade,
  conclusão local, finalização online/offline, visitante, reinício, erro
  permanente, backoff e falha de gravação da fila.
- Não há teste de backup restaurável, quota Web, corrupção da fila, corrupção do
  rascunho, bomba de descompressão, poda de resultados ou round-trip de
  exportação/importação.

## Riscos

1. **Perda total ao desinstalar.** Sem backup de rascunhos e resultados, limpar
   dados apaga o histórico.
2. **Fila ilegível.** Corrupção em `SharedPreferences` pode esconder entregas
   pendentes.
3. **Quota Web.** `localStorage` cheio quebra gravação sem plano B.
4. **Duplicação de conteúdo.** O mesmo exame ocupa várias cópias e pode estourar
   o armazenamento.
5. **Gabarito corrigido apaga retomada.** O hash invalida tentativa por mudança
   de chave.
6. **Backup invisível.** O usuário não sabe que existe `.bak` nem como usá-lo.
7. **Sem teto de descompressão.** Payload grande pode consumir memória.
8. **Falsa sensação de privacidade.** “Privada” não significa criptografada.

## Plano de refatoração da área

### Lote 1 — Backup restaurável

- Criar “Exportar biblioteca” e “Restaurar backup” na Biblioteca, com pacote
  versionado contendo provas, rascunhos, tentativas e resultados.
- Incluir `schemaVersion`, hash, data e contagem; validar antes de aplicar.
- Critério de aceite: exportar em um aparelho e restaurar em outro preserva IDs,
  respostas e resultados; teste de round-trip cobre pacote corrompido.

### Lote 2 — Resiliência de rascunho e fila

- Adicionar `.bak`/versão anterior para rascunho e fila, com leitura de fallback.
- Validar índices de resposta e posição ao carregar; descartar apenas o item
  inválido, preservando o resto.
- Critério de aceite: JSON corrompido não apaga a tentativa; fila recupera a
  última versão válida; testes cobrem ambos.

### Lote 3 — Limites e poda

- Passar `maxUncompressedBytes` ao abrir o pacote local.
- Medir o tamanho total e avisar antes de exceder a quota; no Web, migrar para
  IndexedDB ou compactar a fila.
- Definir retenção de resultados (por tempo ou quantidade) e oferecer limpeza.
- Critério de aceite: prova de 500 questões abre dentro do limite; quota cheia
  gera mensagem acionável; resultados antigos podem ser podados.

### Lote 4 — Deduplicação e hash correto

- Guardar o conteúdo do exame uma vez e referenciar por ID/hash nas tentativas,
  rascunhos e resultados.
- Remover `correctIndex` do hash de tentativa; manter statement/options/mídia.
- Critério de aceite: corrigir gabarito não invalida respostas; duas tentativas
  do mesmo exame não duplicam o conteúdo.

### Lote 5 — Privacidade explícita

- Decidir e documentar se provas privadas serão criptografadas; se não, informar
  que a proteção é o sandbox do aparelho.
- Se criptografar, usar chave do sistema e tratar migração.
- Critério de aceite: texto de privacidade corresponde ao comportamento real;
  teste garante que o backup não expõe mais do que o prometido.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 4 | Persistência, backup automático e fila funcionam no caminho real. |
| Testes | 4 | Cobertura forte de corrupção, concorrência, compressão e idempotência. |
| Acoplamento | 3 | Stores claros, mas conteúdo duplicado e UI conhece detalhes. |
| Clareza | 4 | Nomes, comentários e formatos compreensíveis. |
| Segurança | 4 | Integridade SHA-256 e sandbox; falta decisão de criptografia. |
| Robustez | 3 | Excelente no arquivo; rascunho/fila sem backup e sem teto. |
| Aderência | 3 | Offline e retomada existem; backup restaurável e exportação ampla faltam. |
| Portabilidade | 3 | IO robusto; Web depende de quota de `localStorage`. |

Classificação resultante: **EVOLUIR** — a persistência principal é sólida e deve
ser preservada; o próximo salto é transformar o backup automático em backup
restaurável e proteger rascunho/fila contra corrupção e quota.

## Dependências

- Área 5 para formato do rascunho e tempo por questão.
- Área 6 para formato de resultado e histórico.
- Área 8 para contrato da fila e conflitos.
- Área 10 para mídia e cache de imagens.
- Área 12 para IDs e versões vindos do backend.
- Decisão de produto sobre criptografia, retenção e backup na nuvem.

## O que não foi verificado

- Quota real de `localStorage` em navegadores móveis.
- Comportamento de `FilePicker.saveFile` em Android/iOS/Web.
- Restauração de backup em instalação limpa.
- Tamanho real de uma biblioteca com 90 questões e imagens.
- Migração de instalações antigas com muitos dados.
- Corrupção real de `SharedPreferences` no sistema.
- Backup do sistema operacional (Android Auto Backup/iCloud).

## Links

- [[05 - Focus Mode, timer, navegação e finalização|Área 5 — Focus Mode]]
- [[06 - Tentativas, resultados e pontuação|Área 6 — Resultados]]
- [[08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]]
- [[09 - Importação, OCR, parser e quality gate|Área 9 — Importação]]
- [[10 - Publicação, pacotes, mídia e Storage|Área 10 — Mídia e Storage]]
- [[../../02 - Arquitetura/Mapa de Módulos|Mapa de Módulos]]
- [[Mapa das Áreas|Mapa das Áreas]]
