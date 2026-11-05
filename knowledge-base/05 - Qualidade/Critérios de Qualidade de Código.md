---
tipo: guia
area: critérios de qualidade para a camada nova
status: VALIDADO
classificacao: MANTER
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 8ffbba4431fd1f26c677372fff545b2ff52beabb
confianca: alta
atualizado: 2026-11-05
---

# Critérios de Qualidade de Código (SOLID, Clean Code, módulos)

Nota **normativa**: é a régua que a camada nova do strangler tem que passar, e a
lista do que é verificável por ferramenta versus o que exige leitura humana. Não
mede o app — medir está em
[[Auditoria de Clean Code e SOLID medida]]. Cada regra abaixo vem com **como
verificar**, porque regra sem método de verificação não é critério, é opinião.

## 1. SOLID, como os autores dizem (e não como se repete)

**S — Responsabilidade única.** "Um módulo deveria ter uma, e apenas uma, razão
para mudar"; responsabilidade = *obrigação perante um ator* — não "uma função por
classe". Fonte: [Single Responsibility Principle](https://blog.cleancoder.com/uncle-bob/2014-05-08/SingleReponsibilityPrinciple.html),
[How Solid is Your Code](https://blog.cleancoder.com/uncle-bob/2020-10-18/Solid-Relevance.html).
*Como verificar:* escrever os atores de cada arquivo (produto, banco, UX,
plataforma, fornecedor). Arquivo com ≥2 atores sem relação entre si está violando.
Isto é o oposto de "quebrar arquivo grande em arquivos pequenos".

**O — Aberto/fechado.** Sobre *costuras*, não sobre `if/else`: o comportamento
deve ser extensível sem modificar código existente (Meyer/Henney,
[SOLID deconstruction](https://gotocon.com/dl/goto-amsterdam-2014/slides/KevlinHenney_SOLIDDeconstruction.pdf)).
*Como verificar:* para cada valor novo de enum (`QuestionFormat`,
`AttemptSyncState`, proveniência) contar em quantos sítios é preciso mexer. Um
`switch` exaustivo (erro de compilação) custa 0 surpresas; um
`firstWhere(orElse:)` custa uma mudança silenciosa de comportamento — e é
indistinguível no analyzer.

**L — Substituição de Liskov.** O que se prova do supertipo vale para o subtipo:
pré-condições, pós-condições e invariantes ([Liskov & Wing 1994](https://www.cs.cmu.edu/~wing/publications/LiskovWing94.pdf)).
*Como verificar:* implementação que lança para uma entrada que o tipo aceita, ou
que devolve sentinela (`0`, `false`, `null`) onde o contrato promete valor, é
violação. Teste de caracterização do contrato é o único detector confiável.

**I — Segregação.** A interface é imposta **pelos consumidores**, não pela vontade
de "deixar a classe limpa"; interface com um único consumidor é
sobre-segregação (mesma fonte do S). *Como verificar:* para cada `abstract class`,
contar métodos usados por cada `implements`/consumidor; um cliente que usa 2 de 11
está pagando por 9 — e obrigando todo fake de teste a implementar 11.

**D — Inversão de dependência.** Depender na direção da abstração, com a
**abstração pertencendo ao módulo de alto nível**
 ([The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012-08-13/the-clean-architecture.html)).
Canon Flutter: views sem regra de negócio, repositórios que não se conhecem entre
si, camada de domínio opcional de casos de uso
 ([App architecture guide](https://docs.flutter.dev/app-architecture/guide)).
*Como verificar (grep):* SDK (`supabase_flutter`, `shared_preferences`,
`path_provider`, `http`) proibido fora de `lib/core/backend/**` e
`lib/core/import/**`; construtor com default concreto (`_client ??
Supabase.instance.client`) não é injeção; estático mutável usado como backdoor de
teste é DIP invertida.

## 2. Clean Code verificável em Dart

| Regra | Como verificar hoje | Ferramenta |
|---|---|---|
| Função pequena, um nível de abstração, sem degradação no meio do corpo | leitura `arquivo:linha` do corpo | **nenhum lint oficial** — exige revisão ou `custom_lint` |
| Sem parâmetro booleano posicional | `avoid_positional_boolean_parameters` | lint |
| Erro por exceção tipada, não por código/sentinela | `only_throw_errors`, `avoid_catches_without_on_clauses`, `empty_catches`, `use_rethrow_when_possible` | lint |
| `try` cobrindo só a chamada que falha | corpo do `try` > ~8 linhas ou cobrindo navegação/UI | revisão |
| Sem futuro descartado (fire-and-forget) | `discarded_futures`, `unawaited_futures` | lint |
| Sem chamada dinâmica em `Map<String, dynamic>` | `avoid_dynamic_calls`, `strict-raw-types`, `strict-casts` | analyzer |
| Campos de modelo finais; sem mutação de parâmetro | `parameter_assignments`, `prefer_final_fields`, `unnecessary_late` | lint |
| Nome descreve o efeito colateral | revisão (`is*` que muda estado, `save` que só valida) | revisão |
| Comentário só para intenção/advertência/TODO | `flutter_style_todos`; política de idioma definida pelo dono | lint + revisão |
| DRY = duplicação de **conhecimento**, não de texto | contar definições da mesma regra; divergência entre elas é o achado | revisão |
| YAGNI | ramo de migração que nunca é verdadeiro; DTO que o único chamador descarta | revisão |
| Lei de Demeter / Tell-Don't-Ask | encadeamento `.x.y.z.` e `Map` atravessando camadas | revisão |

Critério operativo para a camada nova: **nenhuma regra da coluna "lint" pode estar
violada** — isso é verificável de graça na esteira. As da coluna "revisão" viram
itens de checklist no ADR/revisão, não promessas.

## 3. Módulos (Ousterhout) — o contrapeso ao "dividir é bom"

Complexidade = estrutura + **amplificação de mudança**; módulo *profundo* tem
interface pequena escondendo comportamento, raso tem interface ≈ implementação
([site do livro](https://web.stanford.edu/~ouster/cgi-bin/book.php)).
Consequência direta para este repo: um arquivo de 2.400 linhas **não é defeito por
tamanho**; dividir uma classe profunda por widget *aumenta* a complexidade total.
*Gate verificável depois de qualquer divisão:* arestas do grafo de imports e
símbolos públicos por 100 linhas não podem crescer; `git show --stat` do mesmo
fluxo deve tocar **menos** arquivos que antes. Programação estratégica (custo
antecipado) vs tática (custo escondido) é o critério para decidir quando a camada
nova merece abstração — só quando já existe segundo uso real.

## 4. Grafo de componentes (canon de componentes + métrica empírica)

- **ADP**: zero ciclos no grafo de imports. Ciclo transforma dois módulos em um só
  para fins de teste e de release. *Verificar:* arestas de `import` → SCC de
  tamanho > 1 (comando em
  [[Auditoria de Clean Code e SOLID medida]]).
- **SDP**: depender na direção da estabilidade; domínio deve ter instabilidade
  `I = Ce/(Ce+Ca)` ≈ 0, adaptadores ≈ 1. *Verificar:* `I` por diretório.
- **Reuse-EQP/CCP** (o que se muda junto deve ficar junto): medido como
  **amplificação de mudança** = arquivos tocados por commit do mesmo fluxo, via
  `git log --name-only`. É a métrica que o post da Datadog
  ("Adventure in Graph Theory") popularizou; o texto original não estava
  acessível no momento desta nota, então a métrica fica aqui **como definição
  adotada**, não como citação confirmada.

## 5. GRASP em uma linha

`Widget`/`State` é **View**. O papel de Controller (primeiro objeto fora da UI
que trata o evento) pertence ao caso de uso/notifier; `await` de repositório
dentro de `build()` ou de `onPressed` é Controller no lugar errado. *Parcialmente
verificável:* `no_logic_in_create_state` (lint) e revisão para o resto.

## 6. O que a ferramenta já garante neste repo

A config atual (`analysis_options.yaml`) já traz `package:flutter_lints`
(20 regras) sobre `lints/recommended` (56) sobre `lints/core` (35) + 2 regras
próprias ≈ **111 regras**, e o analyzer está limpo. Logo, o débito deste app **não
está no que está habilitado** — está exatamente no que nenhuma dessas regras vê:
responsabilidade, dono da abstração, duplicação de conhecimento e escopo de `try`.

Cinco regras extras medem dívida real com custo baixo e sem ruído (números e
locais em [[Auditoria de Clean Code e SOLID medida]]):
`avoid_catches_without_on_clauses`, `discarded_futures`, `avoid_slow_async_io`,
`parameter_assignments`, e os modos `strict-casts` + `strict-raw-types`. Recomendação
(ainda **não aplicada**, mudança de esteira pede aval): habilitá-las com severidade
`warning` e zerar antes de qualquer lote da camada nova. `public_member_api_docs`
não vale a pena neste app (gera 796 diagnósticos de widgets privados).

## 7. Canon de teste aplicável ao strangler

Pirâmide (muitos unit, alguns widget, pouquíssimos E2E),
Arrange-Act-Assert, testar comportamento e não implementação, e — para código
legado — *characterization tests* + *seams* como única forma segura de mudar sem
specificação ([Working Effectively with Legacy Code](https://en.wikipedia.org/wiki/Working_Effectively_with_Legacy_Code),
Feathers). Em Flutter: `flutter test` unit/widget, `integration_test/` para fluxo.
Regra operativa do projeto: **nenhum fluxo migra para a camada nova sem
caracterização verde do fluxo antigo**, e caracterização que só bomba a tela-mãe
não protege a extração de controllers.

## 8. Regras de porta (checklist do lote novo)

1. `lib/domain/**` e `lib/application/**` sem import de SDK ou de `features/**`
   (verificável por grep).
2. Zero SCC no grafo de imports; nenhuma aresta entre `features/*` vizinhas.
3. Uma definição por regra de negócio (`QuestionOutcome`, pontuação, "questão
   válida") — as demais viram chamadas, não cópias.
4. Enum sem `orElse` silencioso em borda de rede/armazenamento: valor desconhecido
   gera erro tipado.
5. Erro de domínio tipado próprio por fronteira, sem `FormatException` genérica
   atravessando camadas e sem sentinela (`0`/`false`/`null`) no lugar de resultado.
6. `try` de uma linha de risco; falha lateral nunca termina em `debugPrint` com
   sucesso devolvido.
7. Abstração declarada onde o consumidor mora; implementação concreta atrás dela;
   construtor sem default concreto.
8. Nenhum `static` mutável em produção; substituição por injeção explícita.
9. Divisão de arquivo só com a métrica do §3 comprovada (arestas e blast radius
   não maiores).
10. Modelo de domínio imutável (campos finais, cópias profundas onde a lista é
    exposta) e com invariantes no construtor.

## Links

[[Auditoria de Clean Code e SOLID medida]] ·
[[Critério de Prontidão para Refatoração Global]] ·
[[../02 - Arquitetura/Mapa de Dependências]] ·
[[../02 - Arquitetura/Arquitetura Alvo]] ·
[[../03 - Domínios/Contratos de Domínio Alvo]] ·
[[../09 - Auditoria/Classificação/Guia de Classificação]]
