---
tipo: area
area: Focus Mode
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/features/quiz/quiz_page.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-03
---

# Focus Mode

## Intenção

Ao resolver uma prova, remover feed e notificações; mostrar questão, total,
progresso, alternativas, navegação, marcador de revisão e estados não
dependentes só de cor. Salvar resposta local imediatamente e sincronizar em
segundo plano. O timer precisa ser configurável e ocultável; retomada deve
continuar do ponto salvo.

## Implementação a auditar

Existe `lib/features/quiz/quiz_page.dart` e serviço local de tentativas. A
auditoria de dimensão, rebuilds por timer, acessibilidade, falha de rede e
retomada ainda precisa ser feita na área correspondente.

## Fonte

[AGENTS.md — Focus Mode](../../AGENTS.md).
