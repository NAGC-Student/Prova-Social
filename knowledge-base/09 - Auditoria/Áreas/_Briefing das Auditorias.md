---
tipo: guia
area: briefing das auditorias profundas
status: VALIDADO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [AGENTS.md, lib/, test/, supabase/, packages/, .github/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Briefing das auditorias profundas

Este arquivo define o contrato de qualidade das notas de área usadas no plano
de refatoração global. Ele não substitui o `AGENTS.md`; complementa o método.

## Objetivo

Produzir, para cada área, uma fotografia verificável do que existe no SHA
`05a8fc1aab92d43f58ad7da8b24e710f9874d281`, separando:

- comportamento observado no código;
- comportamento coberto por teste;
- intenção documentada;
- lacuna ou divergência;
- recomendação de refatoração em lotes pequenos.

Nesta etapa **não há escrita de código de aplicação**. O produto desta auditoria
é documentação, decisão registrada e plano. Nenhum commit, push, tag ou release
deve ser feito sem autorização explícita.

## Regras de evidência

1. Toda afirmação relevante cita `caminho/arquivo.ext:linha` ou um comando cujo
   resultado foi observado.
2. Não inferir comportamento por nome de arquivo, comentário ou documentação.
3. Distinguir **verificado**, **parcial**, **ausente** e **não verificável**.
4. Não inventar números, cobertura, latência, schema remoto ou intenção de
   produto.
5. Quando a documentação divergir do código, registrar a divergência em vez de
   ajustar a interpretação para parecer consistente.
6. Não copiar segredos, respostas privadas, conteúdo de prova ou caminhos
   pessoais para as notas.
7. Não executar `flutter test`, `flutter analyze` ou builds em paralelo nesta
   rodada: a baseline já medida é 296 testes aprovados, 1 opcional ignorado,
   analyzer limpo e falha de formatação em três probes. A leitura de testes
   serve como evidência do que é coberto, não como prova de execução atual.
8. Não alterar código de aplicação, migrations, testes, workflows ou arquivos
   gerados.

## Estrutura obrigatória da nota

```markdown
---
tipo: area
area: <nome>
status: <FUNCIONAL | PARCIAL | AUSENTE | QUEBRADO | NÃO VERIFICÁVEL>
classificacao: <MANTER | EVOLUIR | REFATORAR | RECONSTRUIR | SUBSTITUIR | ABANDONAR | ADIAR | NÃO VERIFICÁVEL>
nivel: {correcao: 0-5, testes: 0-5, acoplamento: 0-5, clareza: 0-5, seguranca: 0-5, robustez: 0-5, aderencia: 0-5, portabilidade: 0-5}
fonte_codigo: [<arquivos e diretórios>]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: <alta | media | baixa>
atualizado: 2026-11-04
---

# <título da área>

## Resumo
Três a seis linhas: objetivo, resultado observado e limite da auditoria.

## Escopo e método
Arquivos lidos, comandos de inventário e o que não foi possível verificar.

## O que faz de fato
Tabela ou lista com comportamento, estado e evidência.

## O que funciona
Capacidades reais, com evidência.

## O que está parcial
Funcionalidades incompletas, heurísticas frágeis, dívida relevante.

## O que está ausente ou quebrado
Lacunas contra o `AGENTS.md`, com referência à seção.

## Divergências documentação × código
Tabela `afirmação | realidade | evidência`.

## Evidência de testes
O que os testes cobrem, o que não cobrem e limites das asserções.

## Riscos
Riscos ordenados por impacto, não por facilidade.

## Plano de refatoração da área
Lotes pequenos, ordem, pré-condições, critérios de aceite e reversão.

## Classificação por critério
Tabela com nota e justificativa de cada um dos oito critérios.

## Dependências
Decisões, dados, credenciais ou outras áreas das quais o plano depende.

## O que não foi verificado
Lista explícita.

## Links
Links para notas centrais, produto, arquitetura e áreas relacionadas.
```

## Rubrica

- **Correção:** o comportamento atende à regra de produto, inclusive casos
  limítrofes.
- **Testes:** há testes significativos, não apenas smoke tests; cobrem falha,
  retry, migração e regressão.
- **Acoplamento:** UI, domínio, persistência e fornecedor estão separados.
- **Clareza:** nomes, contratos e fronteiras permitem mudar uma parte sem
  adivinhar a outra.
- **Segurança:** autorização, RLS, validação, segredos, logs e superfície de
  abuso.
- **Robustez:** falha de rede, processo morto, dado corrompido, retry e
  idempotência.
- **Aderência:** o que o `AGENTS.md` exige existe de fato.
- **Portabilidade:** Web/Android/iOS, tamanhos de tela, acessibilidade,
  redução de movimento e dependência de plataforma.

## Rótulos

- **MANTER:** todos os critérios essenciais ≥ 4.
- **EVOLUIR:** base aproveitável, capacidade pendente.
- **REFATORAR:** comportamento preservável, estrutura inadequada.
- **RECONSTRUIR:** função necessária, implementação inválida e testes de
  caracterização insuficientes.
- **SUBSTITUIR:** existe solução comprovadamente melhor.
- **ABANDONAR:** sem uso e fora de requisito.
- **ADIAR:** válido, mas depende de fundação.
- **NÃO VERIFICÁVEL:** evidência insuficiente.

## Regra de ouro

Uma nota de área não é um resumo da documentação. É uma **discordância
fundamentada** quando o código não cumpre o produto, e um **reconhecimento
fundamentado** quando cumpre. O plano de refatoração deve poder ser executado
por outra pessoa sem reler o código inteiro.
