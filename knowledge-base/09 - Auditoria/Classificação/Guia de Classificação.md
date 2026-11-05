---
tipo: classificacao
area: guia de classificação
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-03
---

# Guia de Classificação

## Rótulos

- **MANTER** — só se Correção, Testes, Acoplamento, Segurança e Portabilidade
  forem todos ≥4.
- **EVOLUIR** — base boa, capacidade pendente.
- **REFATORAR** — comportamento preservável, estrutura inadequada.
- **RECONSTRUIR** — função necessária, implementação inválida; só se testes de
  caracterização não forem suficientes para refatoração.
- **SUBSTITUIR** — há solução melhor comprovada.
- **ABANDONAR** — código sem uso e fora de requisito; declarar substituto quando
  a função for obrigatória.
- **ADIAR** — válido, mas depende de fundação.
- **NÃO VERIFICÁVEL** — evidência insuficiente.

## Notas

Pontuar cada critério de 0–5 e registrar justificativa, arquivo/linha,
confiança, risco, esforço e dependências. A classificação por componente só
começa depois da auditoria profunda das áreas.

Template: [[../../Templates/Classificação]].
