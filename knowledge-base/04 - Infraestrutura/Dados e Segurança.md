---
tipo: area
area: infraestrutura e segurança
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [supabase/migrations/, lib/core/backend/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: baixa
atualizado: 2026-11-05
---

# Dados e Segurança (inventário, não auditoria de segurança completa)

> **Complemento de 2026-11-05:** o inventário profundo pedido abaixo foi feito
> em [[Inventário de Persistência e Dados]] — três trilhas de SQL, 9 tabelas em
> migrations, 11 só em SQL solto, 4 tabelas lidas pelo app sem migração, as
> 4 RPCs usadas, as chaves de armazenamento local e a verificação por hash. Esta
> nota continua válida como declaração de requisitos de segurança; a parte de
> "o que existe" passou para o inventário.

## Componentes vistos

- Supabase para Auth/Postgres/Storage e sincronização.
- Nove migrations versionadas e 15 arquivos SQL (incluindo scripts e testes).
- Stores locais de tentativas e provas; tentativas usam chave de idempotência.
- `packages/paddleocr_android` possui licença própria; não foi localizada licença
  de raiz para o produto.

## Limites de verificação

- Nenhuma conexão ou consulta ao Supabase remoto foi feita; estado aplicado das
  migrations e configuração de RLS não são verificáveis localmente.
- RLS/Storage e credenciais não foram submetidos a auditoria de segurança nesta
  fase.
- `.env.p0` e `.env.supabase.json` existem localmente e são ignorados pelo Git.
  Valores não foram lidos. Nunca copiar esses arquivos para o vault.

## Requisitos para reconstrução

Segredos em secrets manager; chave publicável somente no cliente; RLS para toda
tabela com dados privados; gabarito oficial separado; testes cross-user e
idempotência; nenhuma resposta privada ou conteúdo de prova em log.

## Próxima verificação

Auditar cada migration, função/RPC e política no
[[../09 - Auditoria/Áreas/Mapa das Áreas|inventário profundo]]. Exigir ambiente
isolado antes de testes remotos.
