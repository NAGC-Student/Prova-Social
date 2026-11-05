---
tipo: area
area: núcleo, inicialização, backend e atualizações
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 3, acoplamento: 3, clareza: 4, seguranca: 4, robustez: 2, aderencia: 3, portabilidade: 3}
fonte_codigo: [lib/main.dart, lib/app.dart, lib/core/startup/, lib/core/update/, lib/core/backend/supabase_config.dart, test/ux/startup_test.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Núcleo, inicialização, backend e atualizações

## Resumo

O núcleo é pequeno, legível e faz o essencial: valida a configuração pública do
Supabase, inicializa o cliente, mostra uma splash com a marca e a animação do
anel, respeita redução de movimento e verifica releases do GitHub apenas fora da
Web. A base é boa, mas o ciclo de inicialização não tem timeout nem modo
degradado, a atualização é um modal bloqueante sem opção de ignorar versão e o
tema claro existe no código sem ser alcançável. Classificação: **EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/main.dart`, `lib/app.dart`,
  `lib/core/startup/startup_gate.dart`,
  `lib/core/update/github_release_service.dart`,
  `lib/core/update/update_gate.dart` e
  `lib/core/backend/supabase_config.dart`.
- Leitura dos testes `test/ux/startup_test.dart`,
  `test/github_release_service_test.dart` e `test/supabase_config_test.dart`.
- Inspeção de `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml` e do
  workflow de CI para conferir versão, orientação e canais de distribuição.
- Não foi executado build em aparelho, não foi aberta a API do GitHub em tempo
  real e não foi medido tempo de inicialização. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Bootstrap mínimo | Funcional | `main.dart:9-13` chama `ensureInitialized`, ativa path URL na Web e entrega `_initializeApp` ao app |
| Configuração Supabase em tempo de compilação | Funcional | `supabase_config.dart:26-33` usa `String.fromEnvironment` para URL, chave e ambiente |
| Validação de URL | Funcional | `supabase_config.dart:44-52` exige HTTPS, host, sem credenciais, query ou fragmento |
| Rejeição de chave secreta | Funcional | `supabase_config.dart:87-102` aceita `sb_publishable_` ou JWT com claim `role=anon`; rejeita `service_role` |
| Diagnóstico sem segredos | Funcional | `supabase_config.dart:56-62` expõe somente booleanos; teste confirma que URL/chave não aparecem no log |
| Inicialização do Supabase | Funcional | `main.dart:15-22` chama `Supabase.initialize` com a chave publicável |
| Splash com marca e anel | Funcional | `startup_gate.dart:108-203`; livro de 100 px e anel de 1.750 ms |
| Redução de movimento | Funcional | `startup_gate.dart:46-55, 107, 156-158`; o anel para e as transições viram zero |
| Mensagem após espera | Parcial | `startup_gate.dart:40-42` troca o texto após 2 s, mas não há timeout nem mensagem de espera longa |
| Recuperação de erro | Parcial | `startup_gate.dart:173-196` mostra causa e “Tentar novamente”; o retry recria o future |
| Verificação de atualização | Funcional | `update_gate.dart:20-27` roda uma vez, após o primeiro frame, somente fora da Web |
| Comparação de versão | Parcial | `github_release_service.dart:104-121` compara partes numéricas e ignora sufixo/build |
| Seleção de APK por ABI | Funcional | `github_release_service.dart:85-102`; fallback para universal |
| Abertura do download | Parcial | `update_gate.dart:48-54` abre URL externa e ignora o resultado de `launchUrl` |
| Rota inicial e deep link | Parcial | `app.dart:26-50` decide entre `AuthGate` e `ShareLinkPage` a partir da rota |
| Tema | Divergente | `app.dart:23` fixa `ThemeMode.dark`; `AppTheme.light` existe mas não é usado |

## O que funciona

1. **Configuração pública verificável.** A validação distingue ausência,
   URL inválida e chave secreta, com mensagens que orientam o desenvolvedor sem
   imprimir valores (`supabase_config.dart:64-85`).
2. **Splash fiel à marca.** O símbolo e o anel usam as cores da marca, e a
   splash não depende de asset remoto (`startup_gate.dart:121-141`).
3. **Acessibilidade básica na splash.** Há `Semantics` com rótulo de
   carregamento/erro e o texto muda com o estado (`startup_gate.dart:117-120`).
4. **Atualização não impede a abertura.** Toda falha de rede, API ou plataforma
   é capturada e o app segue (`update_gate.dart:61-65`).
5. **Testes de contrato do núcleo.** Os testes cobrem validação de chave,
   ausência de segredo no log, redução de movimento, erro de configuração e
   seleção de APK (`startup_test.dart`, `supabase_config_test.dart`,
   `github_release_service_test.dart`).

## O que está parcial

### Inicialização sem timeout e sem modo degradado

`_initializeApp` aguarda `Supabase.initialize` sem prazo
(`main.dart:15-22`). Se a inicialização travar, a splash permanece para sempre;
o único texto extra aparece após 2 s (`startup_gate.dart:40-42`), mas não há
timeout, cancelamento nem botão de “continuar offline”. O `FutureBuilder`
(`startup_gate.dart:65-88`) só sai do loading quando o future termina.

Além disso, `SupabaseConfig.validate()` lança antes de qualquer tentativa de
operação local (`supabase_config.dart:64-85`). Um build sem `SUPABASE_URL` ou
sem chave não abre nem o conteúdo local/visitante, contrariando o princípio de
que login é opcional e de que o app deve funcionar offline. O modo degradado
deveria permitir abrir a biblioteca local e o conteúdo já baixado, com aviso de
backend indisponível.

### Atualização bloqueante e sem preferência

`UpdateGate` abre um `AlertDialog` a cada abertura quando há versão nova
(`update_gate.dart:33-60`). Não há “ignorar esta versão”, não há canal
beta/estável e não há registro de que o usuário já recusou. O diálogo é modal e
interrompe a primeira interação, o que contraria a orientação de não bloquear
indevidamente. A URL de download é aberta sem confirmação de hash ou assinatura
(`update_gate.dart:48-54`); a confiança é toda no repositório GitHub.

A comparação ignora build metadata e pré-release
(`github_release_service.dart:104-121`). O endpoint `/releases/latest` já exclui
pré-releases, então o risco imediato é baixo, mas uma tag como `0.7.6-beta.1`
seria comparada como `0.7.6` se algum dia viesse por outro caminho. O número de
build (`+15`) também não participa da decisão.

### Verificação de atualização fora da Web e fora do Android

`UpdateGate` roda em qualquer plataforma que não seja Web
(`update_gate.dart:23`). Em iOS, desktop ou Linux, o serviço pode oferecer um
APK Android porque `_androidAbi()` retorna nulo e o fallback escolhe o APK
universal (`github_release_service.dart:72-101`). Não há verificação de
plataforma antes de exibir o diálogo. O produto parece ter alvo Android/Web, mas
o código não restringe explicitamente.

### Rota inicial e ciclo de vida

`onGenerateInitialRoutes` sempre cria uma única rota com `StartupGate` em volta
de `UpdateGate` (`app.dart:26-34`). O `ShareLinkService.parse` decide se a página
inicial é `AuthGate` ou `ShareLinkPage` (`app.dart:46-51`). Não há tratamento de
link recebido com o app já aberto (`onGenerateRoute` só cobre rotas futuras) nem
teste de deep link em execução real. A configuração Android declara
`provasocial://login-callback` e `https://prova-social.pages.dev/provas`
(`AndroidManifest.xml:34-51`), mas a tela está travada em retrato
(`AndroidManifest.xml:12`).

### Tema claro inalcançável

`app.dart:23` fixa `ThemeMode.dark`. `AppTheme.light` existe e é testado
indiretamente, mas o usuário não tem como escolher claro, escuro ou sistema.
A splash também usa cores escuras fixas (`startup_gate.dart:109, 147-169`), o
que a deixaria inconsistente se o tema claro fosse habilitado sem ajuste.

## O que está ausente ou quebrado

- Timeout/cancelamento da inicialização e opção de entrar em modo local.
- Persistência da decisão de ignorar uma versão.
- Restrição explícita da checagem de atualização ao Android.
- Feedback de falha ao abrir o download.
- Preferência de tema e respeito ao tema do sistema.
- Teste de inicialização que simule future pendente e valide timeout.
- Teste de diálogo de atualização e de recusa/ignorar versão.
- Verificação de assinatura/hash do APK baixado.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Tema claro e escuro” | `ThemeMode.dark` fixo; claro inacessível | `app.dart:23` |
| “Atualização sem bloquear indevidamente” | Diálogo modal em toda abertura | `update_gate.dart:33-60` |
| “Login opcional para explorar e usar recursos locais” | Sem configuração Supabase o app não inicia | `supabase_config.dart:64-85`, `main.dart:15-22` |
| “Splash curta, sem bloquear desnecessariamente” | Sem timeout; pode ficar indefinidamente | `startup_gate.dart:65-88` |
| “PDF runtime inicializa antes do Supabase” (teste) | `main.dart` não passa `beforeSupabaseInitialize`; o pdfrx inicializa sob demanda | `main.dart:17-22`, `supabase_config_test.dart:28-38`, `pdf_text_extractor.dart:149-165` |
| Android mobile-first | Atividade travada em retrato | `AndroidManifest.xml:12` |

## Evidência de testes

- `startup_test.dart:13-47` verifica que a splash mantém o backdrop escuro e não
  um bloco claro.
- `startup_test.dart:48-69` verifica mensagem de configuração ausente e botão de
  retry.
- `startup_test.dart:71-106` verifica livro estático, anel animado e redução de
  movimento; não verifica espera longa nem timeout.
- `github_release_service_test.dart:5-46` cobre comparação simples e escolha de
  APK; não cobre JSON real, falha HTTP, timeout, pré-release, build metadata ou
  ausência de assets.
- `supabase_config_test.dart:11-159` cobre validação, ordem de inicialização,
  rejeição de chave secreta e logs sem segredo. O caso “pdfrx antes do Supabase”
  testa um hook que `main.dart` não usa.

## Riscos

1. **App preso na splash.** Uma inicialização pendente não tem saída; o usuário
   só pode matar o processo.
2. **Build inutilizável por configuração ausente.** Um artefato sem variável de
   ambiente não abre nem o conteúdo local, o que dificulta teste e distribuição.
3. **Atualização intrusiva.** O modal em toda abertura treina o usuário a
   fechar sem ler; não há como adiar de forma persistente.
4. **APK errado em outra plataforma.** Desktop/iOS podem receber convite para
   baixar APK Android.
5. **Download não verificado.** Não há hash/assinatura; comprometimento do
   repositório ou do release seria suficiente para distribuir binário.
6. **Tema inconsistente.** O esforço de tema claro e de contraste fica invisível
   e a splash não acompanha uma futura preferência.

## Plano de refatoração da área

### Lote 1 — Inicialização observável e degradável

- Introduzir timeout configurável em `_initializeApp` e um estado
  `StartupFailure` com ações “Tentar novamente” e “Continuar sem conta”.
- Separar `initializeLocal()` de `initializeRemote()`; o app deve abrir com
  stores locais mesmo sem Supabase, exibindo faixa de backend indisponível.
- Critério de aceite: future pendente termina em estado de erro após o prazo;
  build sem env abre a home local; testes de widget cobrem os dois caminhos.
- Reversão: manter o caminho atual atrás de flag de configuração até o modo
  local estar coberto.

### Lote 2 — Atualização não bloqueante

- Persistir “ignorar esta versão” em `shared_preferences` e limitar a checagem
  ao Android.
- Trocar o diálogo por banner/sheet não modal, com ação “Baixar” e “Depois”.
- Tratar falha de `launchUrl` com mensagem e fallback para a página do release.
- Critério de aceite: testes de `UpdateGate` cobrem versão nova, versão
  ignorada, falha de abertura e plataforma não Android.

### Lote 3 — Tema e splash

- Expor `ThemeMode.system` como padrão e permitir escolha explícita.
- Parametrizar as cores da splash pelos tokens do tema.
- Critério de aceite: testes em claro/escuro e redução de movimento; splash
  mantém contraste nos dois temas.

### Lote 4 — Robustez de release

- Validar URL, plataforma e existência de asset antes de exibir atualização.
- Registrar hash do APK no release e conferir antes de abrir o download, se o
  produto decidir exigir essa garantia.
- Critério de aceite: release sem APK compatível não mostra convite; hash
  ausente ou divergente gera erro explícito.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Inicialização e atualização funcionam no caminho feliz; faltam timeout e modo local. |
| Testes | 3 | Bons testes unitários de configuração/versão; nenhum teste de espera pendente, diálogo ou deep link real. |
| Acoplamento | 3 | Arquivos pequenos e coesos; `main.dart` conhece Supabase diretamente e o app fixa tema. |
| Clareza | 4 | Nomes e fluxos claros; a distinção local/remoto não existe. |
| Segurança | 4 | Validação de chave e logs sem segredos; falta verificação de integridade do APK. |
| Robustez | 2 | Sem timeout, sem modo degradado, download sem tratamento de erro. |
| Aderência | 3 | Splash, redução de movimento e atualização existem; tema e não bloqueio faltam. |
| Portabilidade | 3 | Web é tratada; Android é o alvo real; outras plataformas recebem APK e o Android trava em retrato. |

Classificação resultante: **EVOLUIR** — o núcleo é preservável e pequeno, mas
precisa de estados de falha e de uma política de atualização menos intrusiva.

## Dependências

- Decisão de produto sobre modo visitante/local sem backend.
- Definição de canais de release e de política de atualização.
- Área 15 (CI/CD e releases) para nomes de assets, tags e hash.
- Área 16 (design system) para tema claro/escuro e tokens da splash.
- Área 3 (autenticação) para o comportamento de sessão após o modo degradado.

## O que não foi verificado

- Tempo real de inicialização em Android, iOS, Web e desktop.
- Comportamento de `Supabase.initialize` com rede lenta ou indisponível.
- Recebimento de deep link com o app já aberto.
- API real do GitHub, rate limit e formato dos assets publicados.
- Assinatura e hash dos APKs distribuídos.
- Acessibilidade da splash com leitor de tela real.

## Links

- [[../../00 - Central/Estado Atual|Estado Atual]]
- [[../../02 - Arquitetura/Mapa de Módulos|Mapa de Módulos]]
- [[../Documentação e Divergências|Documentação e Divergências]]
- [[03 - Autenticação, visitante e deep links|Área 3 — Autenticação e deep links]]
- [[15 - CI-CD, releases, site, Web e PWA|Área 15 — CI/CD e releases]]
- [[16 - Design system e componentes|Área 16 — Design system]]
- [[Mapa das Áreas|Mapa das Áreas]]
