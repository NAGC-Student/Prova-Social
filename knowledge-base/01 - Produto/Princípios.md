---
tipo: area
area: princípios do produto
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-03
---

# Princípios obrigatórios

Conforme [AGENTS.md](../../AGENTS.md), a experiência não pode apresentar dados
falsos como reais; deve permitir explorar conteúdo público sem login; exigir
conta apenas para ações persistentes ou sociais; entrar em Focus Mode ao iniciar
uma prova; mostrar procedência; preservar respostas diante de falhas de rede;
priorizar celular, acessibilidade e conexão ruim; responder rapidamente; e não
depender de IA paga para funções estruturais.

## Segurança de produto

- Nunca inferir gabarito.
- Não expor service-role key no cliente.
- Não colocar conteúdo de prova ou respostas privadas em logs.
- Conteúdo público/privado é escolha explícita; publicação requer revisão.
- Estado vazio precisa ser honesto e útil.

## Verificação

São critérios de intenção. A auditoria profunda das **18 áreas** foi concluída
no SHA `05a8fc1`; o placar está em
[[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]] e a consolidação em
[[../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]].
