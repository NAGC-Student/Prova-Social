---
tipo: area
area: publicação, pacotes, mídia e Storage
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 4, seguranca: 4, robustez: 3, aderencia: 2, portabilidade: 4}
fonte_codigo: [lib/features/publish/publish_page.dart, lib/core/backend/exam_publication_service.dart, lib/core/backend/digital_exam_service.dart, lib/core/backend/exam_media_repository.dart, lib/core/backend/content_delivery_repository.dart, lib/core/backend/content_package_service.dart, supabase/migrations/20261101002428_exam_media_publication.sql, supabase/content_delivery_v1.sql]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Publicação, pacotes, mídia e Storage

## Resumo

A publicação funciona de ponta a ponta: o editor valida metadados e gabarito, salva
a cópia local, exige login, confirma a visibilidade pública, publica via RPC e
tenta montar um pacote offline com questões e imagens. O desenho de segurança é
bom: o servidor valida autoria, posição da questão, propriedade do asset e limites
de tamanho; o cliente verifica SHA-256 ao baixar; e o download tem limites de
pacote e de bytes de imagem. As lacunas são de **produto e operação**: a "imagem
da questão" publicada é a **página inteira** do documento, não a figura recortada;
não existem banco de imagens licenciadas, autoria, licença ou recorte; toda prova é
publicada como `community`, mesmo com fonte oficial; o assunto de todas as
questões vira `Geral`; o pacote offline pode falhar em silêncio; e as tabelas de
pacotes (`content_files`) estão em um SQL solto, fora das migrations versionadas.
Classificação: **EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/core/backend/exam_publication_service.dart` (233
  linhas), `digital_exam_service.dart` (314), `exam_media_repository.dart` (256),
  `content_delivery_repository.dart` (143) e `content_package_service.dart` (48).
- Leitura dirigida de `lib/features/publish/publish_page.dart` (2.379 linhas):
  escolha de publicação (`171-247`), importação PDF/JSON (`248-428`), etapas de
  processamento (`428-915`), revisão e edição (`997-2301`), validação
  (`1317-1344`), exportação (`1273-1308`) e `_publish` (`1451-1572`).
- Leitura da migration `20261101002428_exam_media_publication.sql` (209 linhas) e
  de `supabase/content_delivery_v1.sql` (140).
- Leitura dos testes `test/content_package_test.dart`,
  `test/digital_exam_service_test.dart`, `test/exam_media_cache_test.dart` e
  `test/question_media_gallery_test.dart`.
- Não foi feito upload real ao Storage, nem publicação contra o Supabase ativo,
  nem teste de RLS com duas contas. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Escolha entre PDF, JSON e criação manual | Funcional | `publish_page.dart:171-247` |
| Importação de JSON com limite de 4 MB | Funcional | `publish_page.dart:140-170` |
| Processamento com etapas reais | Funcional | `publish_page.dart:428-915` |
| Revisão humana antes de publicar | Funcional | `publish_page.dart:997-2301` |
| Exigência de revisão e gabarito | Funcional | `publish_page.dart:1317-1344` |
| Salvar rascunho local antes de publicar | Funcional | `publish_page.dart:1465`; `1122-1127` |
| Login contextual na publicação | Funcional | `publish_page.dart:1466-1475` |
| Confirmação explícita de visibilidade | Funcional | `publish_page.dart:1476-1498` |
| Publicação relacional via RPC | Funcional | `exam_publication_service.dart:99-137` |
| RPC transacional com mídia | Funcional | `20261101002428...sql:98-168` |
| Validação de autoria e posição da mídia | Funcional | `20261101002428...sql:128-151` |
| Deduplicação de imagem por SHA-256 | Funcional | `exam_media_repository.dart:93-169` |
| Limite de 5 MB por imagem | Funcional | `exam_media_repository.dart:89-91`; `202611...sql:9` |
| Cache LRU de imagens | Funcional | `exam_media_repository.dart:226-255` |
| Download com verificação de hash | Funcional | `exam_media_repository.dart:207-223` |
| Pacote gzip de questões e manifesto | Funcional | `digital_exam_service.dart:65-93` |
| Limites de pacote e descompressão | Funcional | `content_delivery_repository.dart:14-16, 106-132` |
| Fallback para catálogo relacional | Funcional | `digital_exam_service.dart:148-168` |
| Imagem da figura recortada | Ausente | sobe `page.previewBytes` inteiro, `publish_page.dart:1516-1527` |
| Banco de imagens licenciadas | Ausente | nenhuma referência a licença/autoria/crédito em `lib/` |
| Recorte e confirmação da imagem | Ausente | nenhuma UI de crop |
| Publicação como fonte oficial | Quebrado | `p_source_type: 'community'` fixo, `exam_publication_service.dart:80` |
| Preservação do assunto da questão | Quebrado | `'topic': 'Geral'` fixo, `exam_publication_service.dart:64` |
| Falha de pacote visível ao usuário | Ausente | erro só em `debugPrint`, `exam_publication_service.dart:195-197` |
| Coleta de mídia órfã | Parcial | só assets criados na tentativa, `exam_media_repository.dart:173-188` |
| Tabelas de pacote em migration | Quebrado | `content_files` só em `content_delivery_v1.sql` |

## O que funciona

1. **Publicação com validação em duas camadas.** O cliente exige título,
   categoria, fonte, duração, questões revisadas e gabarito completo
   (`publish_page.dart:1317-1344`); o servidor repete as validações e ainda
   limita a 300 questões, 8 MB de questões e 900 imagens
   (`exam_publication_service.dart:32-94`). Não é possível publicar prova
   objetiva sem gabarito.
2. **RPC transacional para mídia.** `publish_exam_with_media` valida cada
   referência, confere que o asset pertence ao usuário e que a posição existe
   antes de chamar `publish_exam`; depois associa as imagens e verifica se todas
   foram inseridas (`20261101002428...sql:128-166`). Se a associação falhar, a
   transação inteira desfaz. Isso evita prova publicada pela metade.
3. **Segurança de Storage coerente.** O bucket `exam-content` é privado, limita
   cada objeto a 25 MB e aceita apenas gzip, binário e imagens webp/svg/png/jpeg
   (`202611...sql:202-207`). As políticas de insert exigem que o caminho comece
   pelo UID e contenha `media` ou `exams/<examId>` de prova do próprio autor
   (`content_delivery_v1.sql:100-116`). Leitura pública só para prova publicada.
4. **Deduplicação por conteúdo.** O asset é endereçado por
   `${user.id}/media/${sha256}.${ext}` e a tabela tem `unique (owner_id, sha256)`
   (`exam_media_repository.dart:106`; `202611...sql:13`). Duas questões que usam
   a mesma página não gastam dois objetos.
5. **Concorrência tratada.** Se duas sessões subirem o mesmo arquivo, o código
   tenta novamente a linha existente por três vezes antes de desistir e remover o
   objeto (`exam_media_repository.dart:118-168`). O asset criado em uma
   publicação que falhou é removido se ainda não estiver associado
   (`exam_media_repository.dart:173-188`).
6. **Integridade no download.** A imagem só entra no cache se o SHA-256 bater
   (`exam_media_repository.dart:211-220`); o pacote só é aberto se o tamanho
   comprimido e o hash baterem (`content_delivery_repository.dart:124-132`). O
   `ContentPackageService.open` valida o tamanho declarado no trailer do gzip e
   o tamanho real depois de descompactar (`content_package_service.dart:30-47`).
7. **Limites no download offline.** Manifesto e questões têm teto de 16 MiB
   descompactados (`digital_exam_service.dart:111-130`), a prova aceita no máximo
   300 questões e 900 imagens, e o total de imagens não pode passar de 12 MiB
   (`digital_exam_service.dart:141-145, 228-230, 269-272`).
8. **Fallback explícito.** Se o pacote não existir ou estiver inválido, o
   download usa o catálogo relacional, que já traz `exam_media` e
   `media_assets` (`digital_exam_service.dart:148-168, 210-227`;
   `exam_repository.dart:35-36`). Prova antiga continua baixável.
9. **Cache com orçamento.** Tanto imagens quanto pacotes usam cache de bytes com
   limite (24 MiB e 16 MiB) e deduplicação de download em andamento
   (`exam_media_repository.dart:44-48, 190-205`;
   `content_delivery_repository.dart:18-20, 75-92`). Um asset maior que o
   orçamento é devolvido mas não retido.
10. **Download offline autocontido.** O `LocalExam` baixado guarda páginas com
    bytes, MIME, hash e alt text, permitindo exibir a prova sem rede
    (`digital_exam_service.dart:273-312`).

## O que está parcial

### A "imagem da questão" é a página inteira

O `AGENTS.md` §11 pede uma aba para enviar imagem do aparelho, escolher imagem já
enviada, pesquisar imagem pública licenciada, informar autoria, licença e URL de
origem, recortar e confirmar antes de salvar.

O que existe é diferente: ao publicar, o app percorre as páginas de origem de cada
questão e envia `previewBytes` da **página inteira** como JPEG
(`publish_page.dart:1500-1529`). Consequências:

- quem abrir a questão vê a página do PDF, não a figura;
- duas questões da mesma página referenciam o mesmo asset (bom para espaço), mas
  ambas mostram a página toda;
- o alt text é genérico (“Página N da questão M”), não descreve a figura;
- não há como enviar uma imagem avulsa, escolher uma imagem já enviada, pesquisar
  banco licenciado, recortar ou confirmar o enquadramento;
- não há autoria, licença, URL de origem nem crédito na tabela `media_assets`
  (`202611...sql:3-14`).

O pipeline de importação até preserva páginas e materiais de apoio
(`imported_document.dart:127-155`), mas a publicação achata isso em páginas
inteiras. A funcionalidade de imagem descrita no produto não foi construída; foi
feita uma aproximação que serve para “não perder a figura”, não para publicar
figuras.

### Toda prova é da comunidade, mesmo com fonte oficial

`ExamPublicationService` envia `p_source_type: 'community'` fixo
(`exam_publication_service.dart:80`) e repete `'community'` no manifesto
(`exam_publication_service.dart:187`). O editor não pergunta se a prova é oficial,
enviada pela comunidade ou não verificada. Com isso:

- uma prova baixada do site oficial da banca continua marcada como
  “Enviado pela comunidade”;
- o `SourceBadge` nunca mostra “Fonte oficial” para conteúdo publicado pelo app;
- o manifesto offline repete a classificação errada.

A tabela `exams` provavelmente aceita `official`, mas o cliente não oferece a
escolha e o servidor não infere pela URL. É uma divergência direta do princípio
“a procedência deve estar sempre visível e correta”.

### Assunto perdido na publicação

Todas as questões são enviadas com `'topic': 'Geral'`
(`exam_publication_service.dart:64`). O editor tem campo de assunto por questão
na revisão, e a importação tenta detectá-lo, mas a publicação descarta. Isso
quebra busca por tópico (área 4), agrupamento por disciplina, recomendações e
estatísticas por assunto. O pacote offline também herda `Geral`.

### Pacote offline pode falhar em silêncio

Depois de publicar, o serviço tenta criar o pacote gzip e sobe questões e
manifesto. Qualquer erro é engolido com `debugPrint`
(`exam_publication_service.dart:195-197`). O usuário vê “Prova publicada” mesmo
que o pacote não exista. O download ainda funciona pelo catálogo relacional, mas:

- o objetivo de distribuir JSON compacto em vez de linhas relacionais não é
  cumprido;
- não há métrica nem aviso de quantas provas estão sem pacote;
- uma falha de Storage por quota, permissão ou migration ausente passa
  despercebida.

Além disso, `DigitalExamService.upload` sobe primeiro `questions.json.gz` e
depois `manifest.json.gz`; se o manifesto falhar, o arquivo de questões fica
órfão em `content_files` e no bucket, sem limpeza
(`digital_exam_service.dart:65-93`).

### Tabelas de pacote fora das migrations

`content_files`, o bucket e as políticas de `exam-content` estão em
`supabase/content_delivery_v1.sql`, um arquivo solto na raiz de `supabase/`. As
migrations versionadas em `supabase/migrations/` só criam `media_assets` e
`exam_media`. Se um ambiente novo for provisionado apenas com
`supabase db push`, faltam:

- a tabela `content_files`;
- as políticas de leitura/escrita de pacote;
- o bucket e a política de `exams/...` no Storage.

O código trata `PGRST202` para RPC ausente, mas não trata tabela ausente no
upload do pacote — ele apenas falha em silêncio. O mesmo vale para
`supabase/digitalization_v1.sql`, que também referencia `content_files`. Isso é
uma divergência entre “schema versionado” e o que está no repositório.

### Sem coleta de órfãos e sem métrica de mídia

`discardIfUnattached` só remove assets criados na tentativa atual. Um asset que
já existia (mesmo hash de uma publicação anterior) e não foi associado continua
no bucket e na tabela para sempre. Também não há rotina para:

- remover assets sem `exam_media`;
- remover pacotes antigos da mesma prova;
- recalcular uso por usuário;
- avisar sobre approaching quota do bucket.

O `unique (owner_id, sha256)` evita duplicata, mas não impede acúmulo.

### Pacote escolhe “mais recente” por nome, não por versão

`readyPackagesForExam` ordena por `created_at` e o download pega o primeiro
`manifest.json.gz` e o primeiro `questions.json.gz`
(`digital_exam_service.dart:103-120`). O manifesto aponta para o
`questionsFileId` correto, então o pareamento é seguro. Mas não há campo de
versão do pacote, nem garantia de que o manifesto mais recente corresponde à
versão publicada atual. Republicar a mesma prova com conteúdo alterado gera um
novo par; o mais recente vence por data. Se dois uploads acontecerem no mesmo
segundo, a ordem é indefinida. Falta `exam_version` explícito no manifesto e na
consulta.

### `content_files` pode ser alterado pelo dono sem validação de consistência

A política de update permite ao dono alterar qualquer coluna, incluindo
`object_key`, `sha256`, `compressed_bytes` e `status`, desde que continue sendo o
dono (`content_delivery_v1.sql:62-65`). Não há validação de que o novo objeto
existe, tem o tamanho declarado ou pertence ao mesmo exame. O download confia nos
metadados para autorizar e limitar; um cliente malicioso com a própria conta pode
criar metadados incoerentes. O impacto é limitado à própria prova, mas enfraquece
a ideia de que o servidor é a fonte de verdade do pacote.

### Publicação legada com associação parcial

Se a RPC transacional não existir, o serviço cai no caminho antigo: publica a
prova e depois associa imagens uma a uma (`exam_publication_service.dart:127-144`).
Se uma associação falhar, lança `PublishedMediaAttachmentException` e a UI avisa
“não publique novamente” (`publish_page.dart:1551-1560`). É uma boa mensagem,
mas não há:

- retry automático das imagens faltantes;
- lista de quais falharam;
- ferramenta para anexar depois;
- reconciliação entre manifesto e banco.

O usuário fica com uma prova pública incompleta e sem caminho de correção.

## O que está ausente ou quebrado

- Envio de imagem avulsa, escolha de imagem existente e busca em banco licenciado.
- Recorte, confirmação de enquadramento e alt text descritivo.
- Autoria, licença, crédito e URL de origem da imagem.
- Classificação correta de procedência (`official`, `community`, `unverified`).
- Preservação do assunto por questão.
- Aviso e retry de falha do pacote offline.
- Coleta de assets e pacotes órfãos.
- `content_files` e políticas de pacote em migration versionada.
- Versão explícita do pacote e ordenação determinística.
- Validação de consistência no update de `content_files`.
- Retry/reconciliação de mídia no caminho legado.
- Teste de publicação real, RLS com duas contas, upload e falha de pacote.
- Teste de download com manifesto e questões de versões diferentes.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Aba para enviar imagem, escolher imagem e pesquisar imagem licenciada” | Só envia páginas inteiras do PDF automaticamente | `publish_page.dart:1500-1529` |
| “Informar autoria, licença e URL de origem” | Nenhum campo; tabela não tem colunas | `202611...sql:3-14` |
| “Recortar e confirmar antes de salvar” | Não existe recorte nem confirmação | nenhuma referência a crop |
| “Fonte oficial / enviado pela comunidade / não verificada” | Toda publicação vira `community` | `exam_publication_service.dart:80, 187` |
| “Assunto por questão” | Publicação força `Geral` | `exam_publication_service.dart:64` |
| “Distribuir JSON e imagens otimizadas” | Pacote existe, mas falha é silenciosa e não há versão | `exam_publication_service.dart:195-197` |
| “Pacotes com hash e integridade” | Sim, no download | `exam_media_repository.dart:214-220`; `content_delivery_repository.dart:127-131` |
| “Bucket configurado por migration” | `content_files` e parte do bucket estão em SQL solto | `supabase/content_delivery_v1.sql` |

## Evidência de testes

- `test/content_package_test.dart` cobre apenas compressão e restauração de JSON
  sem perda.
- `test/digital_exam_service_test.dart:13-...` cobre download de manifesto,
  questões, imagem, verificação de hash e gravação offline com `MockClient`.
- `test/exam_media_cache_test.dart` cobre LRU e orçamento de bytes.
- `test/question_media_gallery_test.dart` cobre descrição acessível da imagem
  original.
- Não existe `test/exam_publication_service_test.dart`.
- Não há teste de upload, deduplicação entre sessões, órfão, falha de pacote,
  RLS de `media_assets`/`exam_media`, Storage, `content_files`, recorte, licença,
  procedência ou assunto.
- O teste de download não cobre pacote com manifesto de uma versão e questões de
  outra, nem imagem acima do limite.

## Riscos

1. **Figura errada.** O usuário vê a página inteira em vez da figura e precisa
   procurá-la no meio do texto.
2. **Procedência mentida.** Prova oficial aparece como comunitária, minando a
   confiança no selo.
3. **Busca degradada.** Todo assunto vira `Geral`, então filtro e recomendação
   por tema não funcionam.
4. **Offline silenciosamente quebrado.** Publicação “bem-sucedida” sem pacote
   reduz a distribuição ao caminho relacional.
5. **Ambiente novo incompleto.** `content_files` ausente quebra o pacote sem
   mensagem clara.
6. **Storage crescendo sem controle.** Órfãos e versões antigas não são
   coletados.
7. **Publicação parcial no caminho legado.** Prova pública sem algumas imagens e
   sem forma de corrigir.
8. **Licenciamento.** Imagem de página de PDF pode violar direito autoral e não
   há metadado para auditar.

## Plano de refatoração da área

### Lote 1 — Procedência e assunto corretos

- Adicionar seletor obrigatório de procedência no editor (`official`,
  `community`, `unverified`) com texto explicativo e URL de fonte quando
  `official`.
- Enviar o assunto real de cada questão; usar `Geral` apenas como fallback
  explícito.
- Persistir a procedência no manifesto e no pacote.
- Critério de aceite: prova oficial publicada exibe “Fonte oficial”; busca por
  assunto encontra a questão; teste de publicação cobre os três valores.

### Lote 2 — Mídia como figura, não página

- Criar uma etapa de mídia na revisão: extrair regiões de figura da página,
  permitir enviar imagem, escolher uma já enviada, recortar, definir alt text e
  confirmar.
- Modelar autoria, licença e URL de origem em `media_assets` (ou tabela
  associativa) e exibir crédito na questão.
- Se não houver banco licenciado na primeira versão, limitar a imagens do próprio
  usuário e deixar o estado “pesquisar imagem pública” explicitamente indisponível.
- Critério de aceite: questão com figura mostra só a figura; alt text descreve;
  licença e autoria ficam visíveis; teste de widget cobre imagem sem licença
  (bloqueada) e com licença.

### Lote 3 — Pacote observável e versionado

- Propagar falha de pacote para a UI com estado “publicada, pacote pendente” e
  botão “Tentar gerar pacote novamente”.
- Incluir `examVersion`/`packageVersion` no manifesto e ordenar por versão, não
  por data.
- Limpar pacotes antigos e questões órfãs após sucesso.
- Critério de aceite: falha de Storage não mostra sucesso silencioso; download
  sempre pega o pacote da versão publicada; pacote antigo é removido.

### Lote 4 — Schema versionado e consistência

- Mover `content_delivery_v1.sql` (e o que ainda for necessário de
  `digitalization_v1.sql`) para migrations idempotentes em
  `supabase/migrations/`.
- Restringir o update de `content_files` ou validar no servidor que objeto,
  tamanho e hash conferem.
- Criar rotina de coleta de assets/pacotes órfãos e métrica de uso.
- Critério de aceite: ambiente criado só com migrations tem bucket, tabelas e
  políticas; teste de RLS cobre update malicioso; rotina remove órfão de teste.

### Lote 5 — Caminho legado e reconciliação

- No fallback sem RPC transacional, registrar quais imagens falharam e oferecer
  “Anexar imagens pendentes”.
- Criar reconciliação entre manifesto e `exam_media` para detectar prova pública
  incompleta.
- Critério de aceite: falha parcial pode ser corrigida sem republicar; painel
  lista provas com mídia faltante.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Publicação e download funcionam; procedência, assunto e figura estão errados. |
| Testes | 2 | Só pacote, download mockado, cache e galeria; publicação e RLS sem teste. |
| Acoplamento | 3 | Serviços separados, mas editor de 2.379 linhas e Storage/DB misturados na UI. |
| Clareza | 4 | Nomes, comentários e mensagens de erro bons; falha de pacote invisível. |
| Segurança | 4 | RLS forte, hash e limites; update de `content_files` frouxo e SQL fora de migration. |
| Robustez | 3 | Transação boa; pacote silencioso, órfãos e versão indefinida. |
| Aderência | 2 | Falta banco de imagens, licença, recorte e procedência correta. |
| Portabilidade | 4 | Funciona em mobile/web; depende de `FilePicker` e Storage. |

Classificação resultante: **EVOLUIR** — a infraestrutura de publicação é segura e
transacional, mas o conteúdo publicado ainda não representa a figura nem a
procedência que o produto promete.

## Dependências

- Área 2 para `sourceType`, `topic` e modelo de mídia.
- Área 6 para versão da prova usada na correção.
- Área 8 para conflito de versão e reenvio.
- Área 9 para extração de figuras e revisão humana.
- Área 12 para migrations, RLS e RPC.
- Área 16 para o componente de crédito/licença e estados de mídia.
- Decisão de produto sobre banco de imagens licenciadas e política de direitos.

## O que não foi verificado

- Upload e download reais no Supabase Storage.
- RLS com duas contas tentando ler/alterar asset alheio.
- Comportamento quando `content_files` não existe no ambiente.
- Tamanho real de um pacote de 80 questões com imagens.
- Publicação de prova com 300 questões e 900 imagens.
- Falha de quota do bucket.
- Recuperação de publicação parcial no caminho legado.
- Compatibilidade de `FilePicker.saveFile` em Android/iOS/Web.

## Links

- [[02 - Domínio, modelos e regras|Área 2 — Domínio]]
- [[04 - Catálogo, busca, feed, biblioteca e perfil|Área 4 — Catálogo]]
- [[06 - Tentativas, resultados e pontuação|Área 6 — Resultados]]
- [[07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
- [[08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]]
- [[09 - Importação, OCR, parser e quality gate|Área 9 — Importação]]
- [[12 - Supabase, schema, RLS e RPCs|Área 12 — Backend]]
- [[../../01 - Produto/Importação e OCR|Importação e OCR]]
- [[Mapa das Áreas|Mapa das Áreas]]
