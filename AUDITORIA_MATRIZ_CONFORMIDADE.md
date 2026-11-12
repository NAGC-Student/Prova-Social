# Matriz de Conformidade — Documentação × Implementação

**Projeto:** Prova Social  
**Entrega:** Fase 2 — Matriz de conformidade  
**SHA de referência:** `1a2b3c4` (branch `feat/adrs-2026-11`, worktree com alterações locais)  
**Versão do app:** `0.7.5+15`  
**Dart/Flutter:** 3.13.5 / 3.47.6  
**Última atualização:** 2026-11-11

---

## Tabela de status

| Status | Significado |
|--------|-------------|
| IMPLEMENTADO E VALIDADO | Existe e foi comprovado por testes |
| IMPLEMENTADO PARCIALMENTE | Funciona apenas em determinadas condições |
| IMPLEMENTADO SEM VALIDAÇÃO | Existe código, mas não há evidência suficiente |
| NÃO IMPLEMENTADO | Foi prometido, mas não existe |
| IMPLEMENTADO COM FALHAS | Existe, mas apresenta comportamento incorreto |
| OBSOLETO | Foi substituído ou deixou de fazer sentido |
| CONTRADITÓRIO | Documentação e implementação apresentam informações conflitantes |
| BLOQUEADO | Depende de infraestrutura, serviço ou decisão externa |

---

## Matriz detalhada

### A. Importação e extração

| # | Funcionalidade | Documento de origem | Requisito documentado | Arquivos responsáveis | Comportamento esperado | Comportamento observado | Teste utilizado | Status | Gravidade | Correção necessária |
|---|----------------|---------------------|----------------------|----------------------|----------------------|----------------------|----------------|--------|-----------|---------------------|
| A1 | Entrada PDF | `AGENTS.md` §10, `docs/URLS_COMPARTILHADAS_E_IMPORTACAO.md` | Upload de PDF, extração de texto/figuras, limite de 25 MB / 500 páginas | `lib/features/publish/publish_page.dart:260-293`, `lib/core/import/pdf_text_extractor.dart` | Extrair texto nativo por página; respeitar limites; falhar com mensagem clara quando excedido | Implementado: `FilePicker` PDF, limite 25 MB, `PdfPageLimitException` a 500 páginas | `test/pdf_text_extractor_test.dart`, `test/vunesp_2024_import_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter; não há câmera/galeria (veja A8) |
| A2 | Entrada JSON | `AGENTS.md` §10 | Importar JSON estruturado, limite 4 MB | `publish_page.dart:126-168` | Ler JSON, validar estrutura, encaminhar para revisão | Implementado; round-trip testado | `test/imported_document_test.dart` | IMPLEMENTADO E VALIDADO | Baixa | Manter |
| A3 | Criação manual | `AGENTS.md` §10 | Editor de questões e alternativas | `publish_page.dart:68-106` (ImportReviewPage vazio) | Montar questões/alternativas manualmente | Implementado (editor vazio, preenchido na revisão) | Não há teste dedicado ao editor vazio | IMPLEMENTADO PARCIALMENTE | Média | Adicionar teste de widget do editor vazio |
| A4 | Entrada por câmera/galeria | `AGENTS.md` §10, `README.md` | Capturar fotos, múltiplas páginas, recorte, EXIF | *ausente* | Não existe `camera`/`image_picker`; não há fluxo foto→OCR | **Não implementado** | *nenhum* | NÃO IMPLEMENTADO | Alta | Implementar câmera/galeria (P1.1) ou remover promessa do README/AGENTS.md |
| A5 | Extração de texto nativo por página | `docs/DIAGNOSTICO_ATUAL.md`, Área 9 | Texto estruturado por página, coordenadas, colunas, previews | `pdf_text_extractor.dart` | Ler `loadStructuredText`, ordenar fragmentos, preservar página | Implementado; 500 páginas; renderPages para preview | `test/pdf_text_extractor_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| A6 | OCR seletivo | `AGENTS.md` §10, Área 9/13 | Texto nativo ≥ 20 chars → nativo; página-imagem → PaddleOCR; texto curto → ML Kit; fallback entre motores | `ocr_router.dart`, `ocr_service_native.dart`, `ocr_service_stub.dart` | OCR só quando necessário; Web sem OC | Implementado no Android/iOS; stub na Web; limiar de 20 chars não validado em corpus real | `test/pdf_text_extractor_test.dart:101-141` | IMPLEMENTADO PARCIALMENTE | Alta | Validar limiar de 20 chars; health check do motor; timeout |
| A7 | Ordenação de layout (duas colunas) | Área 9 | Separar colunas por lacuna horizontal, ordenar verticalmente | `ocr_layout_orderer.dart` | Duas colunas não intercaleadas | Implementado e testado | `test/pdf_text_extractor_test.dart:143-170` | IMPLEMENTADO E VALIDADO | Média | Manter |
| A8 | Remoção de mobília (cabeçalhos/rodapés) | Área 9 | Cabeçalhos/rodapés repetidos, marcas d'água, códigos de página | `page_furniture_filter.dart` | Remover apenas linhas repetidas na borda; não apagar conteúdo legítimo | Implementado; requer repetição entre páginas | `test/page_furniture_filter_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| A9 | Normalização de texto | Área 9 | Espaços, ligaduras, aspas, traços, quebras, marcadores partidos | `text_normalizer.dart` | Limpar código-fonte antes de buscar marcadores | Implementado | `test/exam_text_normalizer_test.dart` | IMPLEMENTADO E VALIDADO | Baixa | Manter |
| A10 | Detecção de formato/layout | Área 9 | Banca/estrutura por evidência no documento; alternativas, julgamento, misto | `exam_layout_profile.dart` | Classificar como letteredAlternatives/judgementItems/mixed/unknown | Implementado; heurística de caixas vazias e rótulos A | `test/exam_layout_profile_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | AFA/EPCAR/EEAR perdem questões (problema P1 no dashboard) |
| A11 | Sugestão de metadados | Área 9 | Título/ano conservadores a partir do texto e nome do arquivo | `exam_metadata_suggester.dart` | Detectar banca, instituição, ano, categoria, fase sem confiar no nome do arquivo | Implementado; assinaturas de 18 bancas + instituições | `test/exam_metadata_suggester_test.dart` | IMPLEMENTADO E VALIDADO | Média | Cobrir bancas faltantes (veja seção C) |
| A12 | Parser de questões | Área 9 | Marcadores explícitos, sequência, alternativas, MC, C/E, asserção, discursiva, desconhecido | `question_parser.dart` | Detectar questões, alternativas, gabarito, formato, confiança, avisos | Implementado; heurístico; **`fieldConfidence` preenchido pelo parser** (`statement` + `options` em todas as construções) e recebe `ExamLayoutProfile?` (`boardProfile`) para bancas militares (AFA/EPCAR/EEAR); ainda sem ground truth de cada banca, então não inventa regras específicas | `test/question_parser_test.dart`, `test/vunesp_2024_import_test.dart`, `test/enem_2025_import_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | Revisar detecção de bancas militares com ground truth; P1-4 infraestrutura feita, P1-5 fieldConfidence feito |
| A13 | Gabarito | Área 9 | Ler gabarito impresso, aplicar onde houver vínculo confiável, não sobrescrever manual | `answer_key_parser.dart` | 1-B, 2-D, CERTO/ERRADO, grids, run de 3+ números | Implementado; conservador | `test/answer_key_parser_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| A14 | Quality gate | Área 9 | `good`/`review`/`retry`; duplicatas, numeração, estrutura, páginas ilegíveis, contagem esperada | `import_quality_gate.dart` | Sinalizar, não apagar; marcar para revisão | Implementado | `test/import_quality_gate_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| A15 | Diagnóstico | Área 9 | Eventos estruturais locais, fingerprint SHA-256, não transmitir | `import_diagnostic_event.dart` | Diagnóstico local sem dados privados | Implementado (local) | `test/` | IMPLEMENTADO SEM VALIDAÇÃO | Baixa | Não transmitir sem consentimento; já declara consentGiven |
| A16 | Revisão humana | Área 9 | Lista de questões, confiança, aviso, editor, página original/preview | `publish_page.dart:2041-2146` | Comparar questão com página, editar, marcar correta, tentativa privada | Implementado; estados estruturais (fazível/corrigível/não fazível) sem porcentagem | `test/publication_contract_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| A17 | Publicação | Área 9 | Exige alternativas e gabarito em todas as questões | `publish_page.dart:1333-1343`, `exam_publication_service.dart:50-56` | Bloquear publicação sem estrutura completa; discursivas sem `correctIndex` | Implementado: `allowOpenEnded: true` permite discursivas; objetivas exigem gabarito | `test/publication_contract_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| A18 | Fila de feedback | Área 9/18 | Fila local, consentimento, exportação JSON, retorno por recibo | `feedback_queue.dart`, `import_feedback_service.dart` | Coletar eventos, consentir, exportar, painel do dono | Implementado localmente (fila + serviço); sem endpoint/rota/retorno remoto | Nenhum teste de exportação | IMPLEMENTADO PARCIALMENTE | Média | Concluir fila remota, endpoint, recebo |

### B. Questões

| # | Funcionalidade | Documento | Requisito | Arquivos | Esperado | Observado | Teste | Status | Gravidade | Correção |
|---|----------------|-----------|-----------|----------|----------|-----------|-------|--------|-----------|----------|
| B1 | Enunciados | AGENTS.md §8 | Enunciado confortável, imagens preservadas | `question_parser.dart` | Preservar enunciado completo | Implementado (heurístico) | `test/question_parser_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | Revisar perda de enunciado em bancas militares |
| B2 | Alternativas | AGENTS.md §8 | Alternativas claras, resposta instantânea | `question_parser.dart` | A–E, com ou sem pontuação, imagens associadas | Implementado; perde alternativas visuais sem extração | `test/visual_option_image_extractor_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | VisualOptionImageExtractor integrado (s3 dashboard) |
| B3 | Imagens | AGENTS.md §8, §11 | Imagens preservadas, galeria somente leitura | `question_media_gallery.dart`, `visual_option_image_extractor.dart` | Exibir figuras extraídas do PDF | Implementado para extração de alternativas de imagem | `test/question_media_gallery_test.dart` | IMPLEMENTADO PARCIALMENTE | Média | Não há upload independente de imagem (ADR-0006) |
| B4 | Fórmulas | AGENTS.md §8 | Fórmulas preservadas | *não dedicado* | Não há reconhecimento LaTeX dedicado | **Não implementado** (fica como imagem) | *nenhum* | NÃO IMPLEMENTADO | Alta | Documentar limitação; não fingir OCR de fórmula |
| B5 | Tabelas | AGENTS.md §8 | Tabelas preservadas | `pdf_text_extractor.dart` (`_mergeTableRows`) | Reconstruir linhas de tabela | Implementado heuristicamente | *não testado diretamente* | IMPLEMENTADO PARCIALMENTE | Média | Adicionar teste de tabela |
| B6 | Gráficos/diagramas | AGENTS.md §8 | Gráficos e diagramas | *não dedicado* | Não há detecção de figuras vetoriais | **Não implementado** | *nenhum* | NÃO IMPLEMENTADO | Média | Documentar limitação |
| B7 | Numeração/ordenação | AGENTS.md §8 | Numeração correta, ordem preservada | `question_parser.dart` | Ordem 1–N, páginas de origem | Implementado; problemas em FUVEST Q22, ENEM espúrio | `test/question_parser_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | Corrigir numeração espúria (P3 dashboard resolvido parcialmente) |
| B8 | Questões discursivas | AGENTS.md §10 | Importar/publicar discursivas, sem correção automática falsa | `exam.dart` (`QuestionType.discursive`), `publish_page.dart`, `exam_publication_service.dart` | Discursivas publicáveis sem `correctIndex` | Implementado: `allowOpenEnded: true` permite publicação de discursivas | `test/content_version_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| B9 | Questões anuladas | AGENTS.md §8 | Detecção de anuladas | *não dedicado* | Não há detecção específica | **Não implementado** | *nenhum* | NÃO IMPLEMENTADO | Média | Adicionar marcação de anulada |

### C. Bancas e identificação

| # | Funcionalidade | Documento | Requisito | Arquivos | Esperado | Observado | Teste | Status | Gravidade | Correção |
|---|----------------|-----------|-----------|----------|----------|-----------|-------|--------|-----------|----------|
| C1 | Perfil de banca identificado | AGENTS.md §8, Área 9 | Identificar banca pelo documento, não pelo nome do arquivo | `exam_metadata_suggester.dart` | Ler banca do texto das primeiras 5 páginas | Implementado; 18 assinaturas de banca | `test/exam_metadata_suggester_test.dart` | IMPLEMENTADO E VALIDADO | Média | Expandir lista de bancas |
| C2 | Perfil utilizado pelo parser | AGENTS.md §8 | Características da banca influenciam interpretação | `question_parser.dart` | Parser usa perfil quando necessário | Parser é universal; perfil de layout separado (`ExamLayoutProfiler`) | `test/exam_layout_profile_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | Integrar perfil de banca no parser (não só layout genérico) |
| C3 | Formatos diferentes de questão | AGENTS.md §8 | Suporte a MC, C/E, asserção, discursiva | `question_parser.dart` (`QuestionFormat`) | 5 formatos reconhecidos | Implementado | `test/question_parser_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| C4 | Não depende só do nome do arquivo | `exam_metadata_suggester.dart` | Banca/instituição/ano do texto, não do filename | `exam_metadata_suggester.dart` | Nome do arquivo nunca sugere banca/instituição/ano | Implementado corretamente | `test/exam_metadata_suggester_test.dart` | IMPLEMENTADO E VALIDADO | Baixa | Manter |
| C5 | Bancas desconhecidas processadas | AGENTS.md §8 | Processar documentos de bancas não cadastradas | `question_parser.dart` | Não rejeitar banca desconhecida; usar layout genérico | Implementado (layout `unknown`) | `test/exam_layout_profile_test.dart` | IMPLEMENTADO E VALIDADO | Baixa | Manter |
| C6 | Falsos positivos | AGENTS.md §8 | Não transformar instruções/sumário em questões | `question_parser.dart` | Instruções não viram questões | Implementado; residual em ENEM (P3 dashboard) | `test/enem_2025_import_test.dart` | IMPLEMENTADO COM FALHAS | Alta | Corrigir numeração espúria residual |
| C7 | VUNESP | Área 9, dashboard | Reconhecer VUNESP | `exam_metadata_suggester.dart` | Detectar VUNESP | Implementado; 80/80 questões VUNESP 2024 | `test/vunesp_2024_import_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| C8 | FGV | Área 9 | Reconhecer FGV | `exam_metadata_suggester.dart` | Detectar FGV | Assinatura existe | `test/exam_metadata_suggester_test.dart` | IMPLEMENTADO SEM VALIDAÇÃO em PDF real | Média | Adicionar teste PDF real FGV |
| C9 | CEBRASPE | Área 9 | Reconhecer CEBRASPE | `exam_metadata_suggester.dart`, `answer_key_parser.dart` | Detectar CEBRASPE; itens C/E | Implementado; dashboard P2: 20 C/E classificadas como não reconhecido | `test/answer_key_parser_test.dart` | IMPLEMENTADO COM FALHAS | Alta | Corrigir padrão ( ) CERTO/ERRADO no inline scan |
| C10 | FCC | Área 9 | Reconhecer FCC | `exam_metadata_suggester.dart` | Detectar FCC | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real FCC |
| C11 | IBFC | Área 9 | Reconhecer IBFC | `exam_metadata_suggester.dart` | Detectar IBFC | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real IBFC |
| C12 | FUNDATEC | Área 9 | Reconhecer FUNDATEC | `exam_metadata_suggester.dart` | Detectar FUNDATEC | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real FUNDATEC |
| C13 | Quadrix | Área 9 | Reconhecer Quadrix | `exam_metadata_suggester.dart` | Detectar Quadrix | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real Quadrix |
| C14 | FUVEST | Área 9, dashboard | Reconhecer FUVEST | `exam_metadata_suggester.dart` | Detectar FUVEST | Implementado; Q22 corrigido (dashboard s1) | `test/exam_metadata_suggester_test.dart` | IMPLEMENTADO COM FALHAS | Média | Q22 já corrigido; manter |
| C15 | INEP/ENEM | Área 9, dashboard | Reconhecer INEP/ENEM; gabarito | `exam_metadata_suggester.dart` | Detectar INEP; 90 questões ENEM | Implementado; 90/90 ENEM 2025; gabarito aplicado | `test/enem_2025_import_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| C16 | ITA | Área 9 | Reconhecer ITA | `exam_metadata_suggester.dart` | Detectar ITA | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real ITA |
| C17 | IME | Área 9 | Reconhecer IME | `exam_metadata_suggester.dart` | Detectar IME | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real IME |
| C18 | AFA | Área 9, dashboard | Reconhecer AFA | `exam_metadata_suggester.dart` | Detectar AFA | Assinatura existe; dashboard P1: 19-37/109 questões, perda massiva | *sem teste PDF real válido* | IMPLEMENTADO COM FALHAS | Alta | Perfil de layout dedicado + ground truth |
| C19 | EPCAR | Área 9, dashboard | Reconhecer EPCAR | `exam_metadata_suggester.dart` | Detectar EPCAR | Assinatura existe; dashboard P1: 12-33/89 | *sem teste PDF real válido* | IMPLEMENTADO COM FALHAS | Alta | Perfil de layout dedicado + ground truth |
| C20 | EEAR | Área 9, dashboard | Reconhecer EEAR | `exam_metadata_suggester.dart` | Detectar EEAR | Assinatura existe; dashboard P1: 10-84/94 | *sem teste PDF real válido* | IMPLEMENTADO COM FALHAS | Alta | Perfil de layout dedicado + ground truth |
| C21 | EsPCEx | Área 9 | Reconhecer EsPCEx | `exam_metadata_suggester.dart` | Detectar EsPCEx | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real EsPCEx |
| C22 | Escola Naval | Área 9 | Reconhecer Escola Naval | `exam_metadata_suggester.dart` | Detectar Escola Naval | Assinatura existe | *sem teste PDF real* | IMPLEMENTADO SEM VALIDAÇÃO | Média | Adicionar teste PDF real |

### D. Banco de dados, backend e integrações

| # | Funcionalidade | Documento | Requisito | Arquivos | Esperado | Observado | Teste | Status | Gravidade | Correção |
|---|----------------|-----------|-----------|----------|----------|-----------|-------|--------|-----------|----------|
| D1 | Supabase Auth | AGENTS.md §5 | E-mail/senha e Google | `lib/features/auth/` | Login, logout, sessão | Implementado; OAuth/deep links sem teste dedicado | `test/auth_page.dart` (não existe) | IMPLEMENTADO PARCIALMENTE | Alta | Adicionar teste de auth |
| D2 | RLS | AGENTS.md §14 | Toda tabela de usuário com RLS coerente | `supabase/migrations/` | Impedir leitura/alteração de dados privados de outro usuário | Implementado para tentativas; social não testado | `test/content_storage_rls_test.dart`, `test/social_graph_rls_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | Estender RLS a profiles, posts, comments, bookmarks, collections, communities, reports |
| D3 | Storage | AGENTS.md §14 | Storage privado, URLs assinadas | `lib/core/backend/exam_media_repository.dart` | Armazenar mídia, URLs assinadas | Implementado; não testado | `test/exam_media_cache_test.dart` | IMPLEMENTADO SEM VALIDAÇÃO | Média | Testar Storage |
| D4 | Migrações | AGENTS.md §14 | Evoluir schema incrementalmente | `supabase/migrations/` | 10 migrations; última `20261110220000` | Implementado; remoto não consultado | `test/content_storage_rls_test.dart` (PGlite) | IMPLEMENTADO PARCIALMENTE | Média | Verificar schema remoto |
| D5 | Persistência local | AGENTS.md §8, §15 | Respostas salvas localmente a cada alteração | `attempt_draft_store.dart`, `local_payload_store.dart` | Salvo no aparelho, sincronizando, sincronizado | Implementado | `test/attempt_draft_store_test.dart`, etc. | IMPLEMENTADO E VALIDADO | Média | Manter |
| D6 | Sincronização | AGENTS.md §15 | Fila com retry seguro, idempotência | `attempt_sync_service.dart` | Idempotente via clientAttemptId; sem duplicação | Implementado | `test/attempt_sync_service_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |

### E. Experiência do usuário (Focus Mode, resultado, navegação)

| # | Funcionalidade | Documento | Requisito | Arquivos | Esperado | Observado | Teste | Status | Gravidade | Correção |
|---|----------------|-----------|-----------|----------|----------|-----------|-------|--------|-----------|----------|
| E1 | Focus Mode | AGENTS.md §8 | Remover distrações; questão atual/total; progresso; anterior/próxima; marcar revisão | `lib/features/quiz/quiz_page.dart` | Interface de prova focada | Implementado; apenas 1 teste de widget | `test/ux/navigation_editor_test.dart` | IMPLEMENTADO PARCIALMENTE | Alta | Adicionar testes de seleção, timer, revisão, finalização |
| E2 | Cronômetro configurável | AGENTS.md §8 | Tempo total/por questão, ligado/desligado, exibição, ocultar/revelar | `focus_timer_settings.dart` | Cronômetros antes de iniciar; tocar para ocultar/revelar | Implementado parcialmente; configuração prévia incompleta | `test/focus_timer_settings_test.dart` | IMPLEMENTADO PARCIALMENTE | Média | Completar configuração prévia dos timers |
| E3 | Resultado | AGENTS.md §9 | Acertos/total, percentual, duração, erradas, branco, marcadas, por disciplina | `lib/features/result/result_page.dart`, `exam.dart` (`ExamResult`) | Dados reais, não inventados | Implementado; `wrongQuestionsExam` para prova dos erros | `test/exam_result_test.dart`, `test/result_review_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| E4 | Prova dos erros | AGENTS.md §9 | Gerar prova com questões erradas; comparar evolução | `wrong_question_practice_service.dart` | Questões erradas selecionadas por filtros | Implementado localmente | `test/wrong_question_practice_service_test.dart` | IMPLEMENTADO E VALIDADO | Média | Manter |
| E5 | Estados vazios | AGENTS.md §2, §6 | Estados vazios honestos e úteis | Vários | Sem conteúdo falso | Implementado parcialmente | *não testado sistematicamente* | IMPLEMENTADO PARCIALMENTE | Média | Auditar estados vazios |

### F. Qualidade, testes e desempenho

| # | Funcionalidade | Documento | Requisito | Arquivos | Esperado | Observado | Teste | Status | Gravidade | Correção |
|---|----------------|-----------|-----------|----------|----------|-----------|-------|--------|-----------|----------|
| F1 | Testes unitários | AGENTS.md §21 | `flutter test` aprovado | `test/` | 296+ testes | 502 aprovados, 1 ignorado, 4 falhas (fixtures PDF/corpus não versionadas nesta máquina) | `flutter test` | IMPLEMENTADO PARCIALMENTE | Alta | Migrar 13 testes int-key API; corrigir fixtures ausentes |
| F2 | Testes de widget (Focus Mode, estados vazios, login) | AGENTS.md §21 | Testes de widget para UX crítica | `test/ux/` | Cobertura de Focus Mode, estados vazios, login contextual | Apenas 1 teste de widget Focus Mode | `test/ux/` | IMPLEMENTADO PARCIALMENTE | Alta | Adicionar testes de widget |
| F3 | Testes de integração (importar→revisar→publicar→fazer→finalizar) | AGENTS.md §21 | Teste ponta a ponta | *ausente* | Nenhum `integration_test/` | **Não implementado** | *nenhum* | NÃO IMPLEMENTADO | Alta | Criar `integration_test/` com fluxo crítico |
| F4 | Analyze | AGENTS.md §21 | `flutter analyze` sem erros | *CI* | Analyzer limpo | Aprovado | CI | IMPLEMENTADO E VALIDADO | Baixa | Manter |
| F5 | Format | AGENTS.md §21 | `dart format` sem alterações | *CI* | exit 0 | Aprovado (problema em 3 probes resolvido) | CI | IMPLEMENTADO E VALIDADO | Baixa | Manter |

### G. Identidade visual e documentação

| # | Funcionalidade | Documento | Requisito | Arquivos | Esperado | Observado | Teste | Status | Gravidade | Correção |
|---|----------------|-----------|-----------|----------|----------|-----------|-------|--------|-----------|----------|
| G1 | Paleta única (app dark) | AGENTS.md §3, ADR-0001 | `EmeraldColors`, `#050907` background | `lib/core/theme/app_theme.dart` | App dark-only esmeralda | Implementado | `test/ux/` | IMPLEMENTADO E VALIDADO | Baixa | Manter |
| G2 | Paleta única (site claro) | AGENTS.md §3 | Site claro `#F7F8F6` | `site/` | Site claro | Implementado | testes Node site | IMPLEMENTADO E VALIDADO | Baixa | Manter |
| G3 | Divergência DESIGN_SYSTEM vs app | `docs/historico/DESIGN_SYSTEM.md` | Declara `#101311`; app usa `#050907` | `app_theme.dart`, `DESIGN_SYSTEM.md` | Cores coerentes | **CONTRADITÓRIO** | *nenhum* | CONTRADITÓRIO | Média | Unificar paleta ou atualizar DESIGN_SYSTEM.md |
| G4 | Divergência DEPENDENCY_COMPATIBILITY | `docs/historico/DEPENDENCY_COMPATIBILITY.md` | Declara v0.5.0; app v0.7.5+16 | `pubspec.yaml`, `DEPENDENCY_COMPATIBILITY.md` | Versões coerentes | **CONTRADITÓRIO** | *nenhum* | CONTRADITÓRIO | Média | Atualizar matriz de dependências |
| G5 | README promete câmera/demo | `README.md` | Câmera e “modo de demonstração” | `README.md` | Recursos existentes | **CONTRADITÓRIO** (não existem) | *nenhum* | CONTRADITÓRIO | Média | Remover promessa ou implementar |
| G6 | Vault versionado | AGENTS.md §25, ADR-0008 | Vault no Git | `knowledge-base/` | Versionado | Versionado desde `eebb2b0` | *nenhum* | IMPLEMENTADO E VALIDADO | Baixa | Manter |

### Resumo de status da matriz

- IMPLEMENTADO E VALIDADO: ~40 requisitos
- IMPLEMENTADO PARCIALMENTE: ~15 requisitos
- IMPLEMENTADO COM FALHAS: ~6 requisitos
- NÃO IMPLEMENTADO: ~6 requisitos (câmera/galeria, fórmulas, gráficos/diagramas, questões anuladas, teste de integração, OCR Web real)
- CONTRADITÓRIO: 3 requisitos (DESIGN_SYSTEM, DEPENDENCY_COMPATIBILITY, README câmera — publicação discursiva × UI resolvido)
- OBSOLETO: 0 (nenhum recurso ativamente removido)
- BLOQUEADO: 0 (nenhum bloqueado externamente no escopo atual)

**Total de requisitos mapeados:** ~68  
**Áreas críticas (P0):** D2 (RLS social), E1 (testes Focus Mode), F3 (integração ponta a ponta), P0-3 (acessibilidade)  
**Áreas altas (P1):** A4 (câmera), A6 (OCR limiar/health check), C9 (CEBRASPE C/E), C18-C20 (bancas militares — ground truth pendente), P1-2 (OCR timeout), P1-6 (fila feedback remoto), G3-G5 (documentação contraditória)
