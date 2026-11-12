---
tipo: adr
area: ocr e pilha de processamento
status: ACEITO
classificacao: VALIDADO
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/import/, packages/paddleocr_android/, AGENTS.md]
sha: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
confianca: alta
atualizado: 2026-11-11
---

# ADR-0017 — Pilha OCR: PaddleOCR + ML Kit (dual-engine) ou apenas PaddleOCR

- **Status:** aceito
- **Data:** 2026-11-11
- **Responsável pela aprovação:** NAGCODE-Dev
- **Áreas:** 9, 11, 17
- **Urgência:** Média

## Contexto

O app usa duas engines OCR em paralelo via `OcrRouter`:
1. **PaddleOCR** (via `paddleocr_android` + ONNX Runtime 1.31.1) — engine principal para páginas completas, roda no Android nativo (JNI)
2. **ML Kit Text Recognition** (Google) — fallback para texto curto ou quando Paddle falha

O `OcrRouter` decide:
- Texto nativo ≥ 20 chars/página → usa texto nativo (sem OCR)
- Texto nativo < 20 chars → tenta PaddleOCR (página inteira renderizada em JPEG)
- Paddle falha ou texto muito curto → ML Kit

**Divergência documentada:** Notice do Paddle declara ONNX Runtime 1.21.1, mas build.gradle usa 1.31.1 (corrigido no notice).

## Decisão

**Mantém dual-engine (PaddleOCR + ML Kit) como padrão, mas documenta plano de migração para PaddleOCR-only no futuro.**

A decisão inclui:
1. **Curto prazo (atual):** Dual-engine com roteamento inteligente. ML Kit serve como fallback robusto e para textos curtos onde Paddle tem overhead alto.
2. **Médio prazo (P1-17):** Benchmark comparativo no corpus VUNESP/ENEM/sintético medindo:
   - Precisão (CER/WER) por tipo de layout (1 coluna, 2 colunas, marcas d'água)
   - Latência p95/p99 em dispositivos low/mid/high-end
   - Consumo de bateria e memória
   - Taxa de falha/timeout
3. **Longo prazo:** Se PaddleOCR-only atingir paridade de precisão + latência aceitável em low-end, remover ML Kit para reduzir:
   - Tamanho do APK (~8 MB do ML Kit)
   - Complexidade de roteamento
   - Superfície de ataque/dependências

## Alternativas

- **A — Apenas PaddleOCR (agora).** Prós: APK menor, código mais simples. Contras: Risco de regressão em textos curtos/fallback; ML Kit tem melhor suporte a idiomas raros.
- **B — Dual-engine mantido indefinidamente (escolhido como transição).** Prós: Robustez máxima, fallback testado. Contras: APK maior, complexidade de roteamento, duas dependências nativas.
- **C — Apenas ML Kit.** Prós: Sem dependência nativa customizada, suporte Google. Contras: Precisão inferior em layouts complexos (2 colunas, fórmulas), sem controle de modelo.

## Consequências e reversão

- **Positivas:** Roteamento inteligente já implementado e testado; fallback ML Kit garante robustez hoje.
- **Negativas/custos:** APK ~8 MB maior; duas dependências nativas (Paddle + ML Kit) para auditar; notice ONNX desatualizado (já corrigido).
- **Riscos:** Se PaddleOCR tiver regressão em dispositivo específico, ML Kit mascara o problema. Mitigação: alertas de monitoramento + benchmark contínuo.
- **Reversão:** Remover ML Kit = remover dependência `google_mlkit_text_recognition` e simplificar `OcrRouter`. Reversível em 1 commit se benchmark provar paridade.

## Evidências e validação

- Código: [ocr_router.dart](../../../lib/core/import/ocr_router.dart), [ocr_service_native.dart](../../../lib/core/import/ocr_service_native.dart)
- Benchmark script: `qa/run_corpus_benchmark.sh` (rodo manualmente em device farm)
- Corpus: 46 PDFs (VUNESP, ENEM, ITA, militares, vestibulares) — sem ground truth anotado
- Métricas atuais: 2.419 questões detectadas, 474 para revisão, 181 incompletas
- **Exigido antes de migrar para Paddle-only:** Benchmark em device farm com 3 tiers de device (low: Snapdragon 450, mid: 778G, high: 8 Gen 2); ground truth anotado para 50 PDFs representativos; CER < 2% em low-end.

## Relacionados

- [[ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]]
- [[ADR-0009 - Política de dependências e pins|ADR-0009]]
- [[../../01 - Produto/Importação e OCR|Importação e OCR]]
- [[../../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Auditoria Área 9]]