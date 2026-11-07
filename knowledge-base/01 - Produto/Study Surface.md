---
tipo: area
area: design system
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/theme/app_theme.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-03
---

# Study Surface

## Intenção visual

Marca Prova Social, com símbolo de livro aberto; superfícies claras ou escuras
com contraste; verde reservado para ações/estados de marca; listas compactas em
vez de cards gigantes; tipografia legível; conteúdo central limitado em desktop;
alvos de toque adequados; redução de movimento respeitada.

Tokens principais da intenção clara: fundo `#F7F8F6`, superfície `#FFFFFF`,
texto `#171A18`, secundário `#68706B`, borda `#E3E7E4`, marca `#16A36A` e perigo
`#DC4C4C`. Paleta escura base: fundo `#101311`, superfície `#181C19`, texto
`#F3F5F3`, borda `#2A302C`.

## Implementação observada

Existe tema compartilhado em `lib/core/theme/app_theme.dart`. O inventário
inicial não fez comparação token por token nem verificação visual em dispositivos.
Classificação permanece pendente.

## Fonte

[AGENTS.md — identidade visual](../../AGENTS.md) e
[DESIGN_SYSTEM.md](../../docs/historico/DESIGN_SYSTEM.md).
