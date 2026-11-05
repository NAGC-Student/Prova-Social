---
tipo: area
area: autenticação, visitante e deep links
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 4, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 3}
fonte_codigo: [lib/features/auth/, lib/features/onboarding/, lib/core/navigation/share_link_service.dart, lib/features/share/share_link_page.dart, lib/core/backend/auth_repository.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Autenticação, visitante e deep links

## Resumo

O caminho principal funciona: visitante explora e resolve sem conta, login por
e-mail/senha e Google usa o Supabase Auth, o onboarding é pulável, e os links
`/provas/{id}` e `/provas/{id}/questoes/{id}` são validados e abertos no app. As
maiores lacunas são a recuperação de senha incompleta, a ausência de reenvio de
confirmação, a falta de teste de deep link real e o acoplamento da home ao
cliente Supabase em vez do repositório. Classificação: **EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/features/auth/auth_page.dart` (364 linhas),
  `auth_gate.dart` (45), `lib/core/backend/auth_repository.dart` (47),
  `lib/core/navigation/share_link_service.dart` (36) e
  `lib/features/share/share_link_page.dart` (187).
- Leitura de `lib/features/onboarding/onboarding_page.dart` (494 linhas) e de
  `lib/app.dart` (rotas).
- Inspeção de `android/app/src/main/AndroidManifest.xml`, `web/index.html`,
  `site/_redirects` e `supabase_config.dart` para redirects.
- Leitura dos testes `onboarding_responsive_test.dart`,
  `share_link_service_test.dart` e `ux/startup_test.dart`.
- Não foi executado login real, OAuth Google, confirmação de e-mail nem
  recebimento de link no Android/Web.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Onboarding com três passos e “Pular” | Funcional | `onboarding_page.dart:20-39, 85-89` |
| Entrar sem conta | Funcional | `onboarding_page.dart:143-152` |
| Login e-mail/senha | Funcional | `auth_page.dart:56-84`, `auth_repository.dart:29-33` |
| Cadastro com nome | Funcional | `auth_page.dart:60-68`, `auth_repository.dart:18-27` |
| Confirmação de e-mail | Parcial | `auth_page.dart:66-68` mostra aviso, mas não há reenvio |
| Google OAuth | Funcional | `auth_repository.dart:35-41` |
| Recuperar senha | Parcial | `auth_repository.dart:43-44` envia link; não há tela de nova senha |
| Sessão observada na home | Funcional | `home_page.dart:59-77` escuta `onAuthStateChange` |
| Ações autenticadas contextuais | Parcial | `home_page.dart:616-660`; cada chamador decide continuar |
| Deep link de prova/questão | Funcional | `share_link_service.dart:16-35`, `share_link_page.dart:21-63` |
| Redirect Web | Funcional | `supabase_config.dart:35-38` aponta para `/app/` |
| Redirect Android | Funcional | `auth_repository.dart:15-16` e `AndroidManifest.xml:34-41` |
| Recuperação de senha no app | Ausente | nenhuma rota/tela de `updateUser` |
| Reenvio de confirmação | Ausente | nenhuma chamada `resend` |
| Biografia/avatar de perfil | Ausente | perfil só mostra nome/e-mail (área 4) |

## O que funciona

1. **Visitante real.** A home carrega catálogo público e a biblioteca local sem
   sessão; `savedExamIds` e `savedExamModels` retornam vazio quando não há
   usuário (`exam_repository.dart:102-104, 253-255`).
2. **Login contextual com intenção.** `_requireAccount` explica por que a conta
   é necessária e oferece “Continuar explorando”
   (`home_page.dart:616-660`). Quem chama `_toggleSave` só executa a ação depois
   de `true`, então o salvamento é retomado após login
   (`home_page.dart:393-398`).
3. **Redirects sem localhost.** Web usa `WEB_AUTH_CALLBACK` com padrão
   `https://prova-social.pages.dev/app/`; Android usa
   `provasocial://login-callback` (`supabase_config.dart:35-38`,
   `auth_repository.dart:15-16`).
4. **Deep link validado.** Só aceita UUID v1–v8 e caminho `/provas/...`; rejeita
   traversal (`share_link_service.dart:16-35`, teste
   `share_link_service_test.dart:19-22`).
5. **Página pública sem sessão.** `ShareLinkPage` busca prova pública, mostra
   procedência, questão e discussão; o botão de resolver abre o quiz
   (`share_link_page.dart:27-160`).
6. **Onboarding responsivo.** Testes cobrem desktop e paisagem sem overflow
   (`onboarding_responsive_test.dart:8-70`).

## O que está parcial

### Recuperação de senha não fecha o ciclo

`sendPasswordReset` envia o link com redirect para `/app/` ou para o esquema
customizado (`auth_repository.dart:43-44`), mas o app não tem rota, tela ou
chamada de `updateUser` para definir a nova senha. O link provavelmente abre a
home; o usuário não consegue concluir a recuperação. Isso é uma lacuna de
produto, não apenas de UI.

### Confirmação de e-mail sem reenvio

No cadastro, se `response.session == null`, a tela apenas informa “Confira seu
e-mail” (`auth_page.dart:66-68`). Não há botão de reenviar, nem orientação para
verificar spam, nem estado de “e-mail já confirmado”. Se o e-mail se perder, o
usuário fica sem caminho.

### Intenção preservada apenas onde o chamador implementa

O mecanismo funciona em salvar e em algumas ações, mas é manual. Não há um
objeto de “intenção pendente” compartilhado; cada tela precisa lembrar de
retomar. A discussão (`question_discussion.dart`) e o quiz têm callbacks
próprios. Uma nova ação autenticada pode facilmente esquecer o retorno.

### Deep link real não testado

`ShareLinkService.parse` é testado, mas não há teste de integração que abra o app
com `provasocial://` ou `https://prova-social.pages.dev/provas/...` e confirme a
tela. O Android declara o host e o prefixo (`AndroidManifest.xml:43-51`), mas o
`site/_redirects` só cobre `/provas/*` para `/app/index.html`; não há prova de
que o link com dois segmentos (`/provas/{id}/questoes/{id}`) chega intacto ao
Flutter Web.

### Acoplamento ao cliente Supabase

A home usa `Supabase.instance.client.auth` diretamente em vários pontos
(`home_page.dart:62, 166, 598, 617, 694, 1437, 1847, 2349`), enquanto o login usa
`AuthRepository`. Isso duplica regras de sessão e dificulta testar visitante,
expiração e logout sem inicializar o Supabase real.

### Gate de onboarding engole falha de armazenamento

Se `SharedPreferences.getInstance()` falhar, `AuthGate` define
`completed = true` (`auth_gate.dart:31-35`), pulando o onboarding em vez de
mostrar erro. É uma escolha de não bloquear, mas esconde a falha e pode levar o
usuário direto para a home sem contexto.

## O que está ausente ou quebrado

- Tela de definição de nova senha após o link de recuperação.
- Reenvio de e-mail de confirmação e estado de confirmação.
- Teste de integração de deep link Android/Web.
- Objeto único de intenção pós-login.
- Uso de `AuthRepository` em toda a UI.
- Tratamento de sessão expirada com mensagem clara.
- Exclusão de conta e privacidade (não exigida nesta fase, mas ausente).
- iOS: sem configuração de URL scheme no repositório.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Corrigir login Google/e-mail e deep links” | Login e links principais existem; recuperação de senha não conclui | `auth_repository.dart:43-44`; sem tela de update |
| “Preservar a intenção anterior ao login” | Só onde o chamador retoma manualmente | `home_page.dart:616-660` |
| “Android retorna ao app por URI configurada” | Declarado no manifesto e no repositório | `AndroidManifest.xml:34-41` |
| “Web retorna ao domínio oficial” | Padrão `/app/`, mas depende da allowlist do Supabase | `supabase_config.dart:35-38` |
| “Login opcional para explorar” | Implementado; visitante tem biblioteca local e catálogo | `home_page.dart:1437-1552` |

## Evidência de testes

- `share_link_service_test.dart:8-22` cobre construção, parsing e rejeição de
  rota malformada.
- `onboarding_responsive_test.dart:8-70` cobre largura de desktop e paisagem.
- `startup_test.dart` não cobre autenticação.
- Não há teste de `AuthPage`, fluxo de cadastro, erro de credencial, OAuth,
  recuperação de senha, reenvio, sessão expirada, logout ou deep link real.
- `home_page` não tem teste dedicado de visitante; a cobertura de navegação
  existe em `test/ux/navigation_editor_test.dart`, mas não substitui um teste de
  sessão.

## Riscos

1. **Usuário preso sem recuperar a conta.** O link de senha não tem tela de
   conclusão.
2. **Cadastro sem saída.** E-mail de confirmação perdido não pode ser reenviado.
3. **Regressão de visitante.** Uso direto de `Supabase.instance` pode lançar em
   teste ou em modo local, quebrando a promessa de explorar sem conta.
4. **Deep link quebrado em produção.** Parsing correto não prova entrega pelo
   sistema operacional ou pela hospedagem.
5. **Intenção perdida.** Nova ação autenticada pode não retomar o fluxo.
6. **Mensagem técnica.** `AuthException` desconhecida retorna `error.message`
   cru, possivelmente em inglês.

## Plano de refatoração da área

### Lote 1 — Fechar recuperação e confirmação

- Criar rota/tela de “definir nova senha” que escute o token do Supabase e
  chame `updateUser(password:)`.
- Adicionar “Reenviar confirmação” com cooldown e mensagem de sucesso/erro.
- Critério de aceite: teste de widget cobre link válido, link expirado e
  reenvio; nenhum caminho termina em tela morta.

### Lote 2 — Sessão centralizada

- Substituir `Supabase.instance.client.auth` na UI por `AuthRepository` injetado
  ou por um `AuthState` observável.
- Definir um `PendingIntent` reutilizável para salvar, publicar, comentar e
  seguir.
- Critério de aceite: home, perfil, biblioteca e share link funcionam com um
  fake de auth; visitante não inicializa cliente real em teste.

### Lote 3 — Deep link verificável

- Adicionar teste de integração Android/Web para `/provas/{id}` e
  `/provas/{id}/questoes/{id}`.
- Confirmar `.well-known/assetlinks.json` e a allowlist de redirect do Supabase.
- Critério de aceite: link abre a prova correta com app fechado e aberto.

### Lote 4 — Mensagens e estados

- Mapear códigos de erro conhecidos e usar mensagem humana; manter detalhe
  técnico apenas em log.
- Tratar sessão expirada durante ação com reautenticação contextual.
- Critério de aceite: testes de erro de credencial, e-mail não confirmado,
  sessão expirada e rede indisponível.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Login, visitante e links principais funcionam; recuperação/confirmação incompletas. |
| Testes | 2 | Só parsing de link e onboarding; nenhum fluxo de auth. |
| Acoplamento | 3 | Repositório existe, mas a UI usa o cliente Supabase direto. |
| Clareza | 4 | Fluxos e telas legíveis. |
| Segurança | 3 | Redirects corretos e sem localhost; falta prova de allowlist e de deep link. |
| Robustez | 2 | Sem reenvio, sem nova senha, erro de prefs esconde onboarding. |
| Aderência | 2 | Falta o ciclo completo de conta exigido pelo produto. |
| Portabilidade | 3 | Android e Web configurados; iOS ausente. |

Classificação resultante: **EVOLUIR** — a autenticação principal está de pé, mas
o ciclo de conta e a verificabilidade de deep links ainda não fecham.

## Dependências

- Configuração de redirect URLs no painel do Supabase (não versionada).
- `.well-known/assetlinks.json` no domínio publicado.
- Área 15 para deploy do site e do Web app.
- Área 4 para perfil e biblioteca.
- Área 11 para login contextual em discussões.

## O que não foi verificado

- Login real por e-mail e Google no app publicado.
- Entrega de e-mail de confirmação/recuperação.
- Allowlist de redirect do projeto Supabase ativo.
- Deep link com app fechado, aberto e em navegador.
- Sessão expirada e refresh token.
- iOS e desktop.

## Links

- [[01 - Núcleo, inicialização, backend e atualizações|Área 1 — Núcleo]]
- [[04 - Catálogo, busca, feed, biblioteca e perfil|Área 4 — Catálogo e perfil]]
- [[11 - Social, discussões, comunidades e denúncia|Área 11 — Social]]
- [[15 - CI-CD, releases, site, Web e PWA|Área 15 — Distribuição]]
- [[../../01 - Produto/Navegação e Visitante|Navegação e Visitante]]
- [[Mapa das Áreas|Mapa das Áreas]]
