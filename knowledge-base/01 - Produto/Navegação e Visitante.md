---
tipo: area
area: navegação
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/app.dart, lib/features/auth/auth_gate.dart, lib/features/home/home_page.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-03
---

# Navegação e visitante

## Intenção

Em celular, navegação compacta: Início, Explorar, Publicar, Biblioteca e Perfil.
Em desktop, sidebar com o mesmo modelo mental. Visitantes podem pesquisar e
experimentar conteúdo público; login contextual é necessário para ações
persistentes/sociais e deve preservar a intenção original.

## Verificação pendente

Arquivos de aplicação e rotas foram identificados, mas não foi concluída uma
auditoria fluxo a fluxo, nem teste E2E autenticado. Não declarar o ciclo de login
e retorno à ação validado.

## Fonte

[AGENTS.md — navegação e visitante](../../AGENTS.md).
