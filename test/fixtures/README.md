# PDF de QA do importador

`synthetic_two_column_80_questions.pdf` é um fixture sintético, criado no
próprio projeto exclusivamente para validar a extração de texto e a importação
de 80 questões distribuídas em duas colunas.

O manifesto `import_corpus.json` registra o hash do PDF, a procedência e os
limites de uso, além do hash do parser e das expectativas usadas como snapshot
de regressão. Mudanças intencionais no fixture ou no parser exigem revisar e
atualizar esse snapshot junto dos testes. O PDF VUNESP também consta no
manifesto como fornecido pelo responsável para QA local; o status de licença
está explicitamente não verificado, e isso não autoriza catálogo ou
redistribuição.

- Não contém prova real, questão de concurso, banca, instituição ou texto
  extraído da internet.
- Não usar no catálogo, na home, em screenshots que o apresentem como conteúdo
  real, nem em produção.
- Não implica licença ou autorização para redistribuir provas de terceiros.
- As respostas do exercício fictício usam a regra `3n + 2`; o gabarito correto
  é a alternativa C em cada questão.

## Política por item do manifesto

Toda entrada de `import_corpus.json` declara, em `source`, os campos
obrigatórios `kind`, `description`, `licenseStatus` (string não vazia),
`allowedForTesting` (bool) e `allowedForProductContent` (bool); em `document`,
`path` e `sha256`. Material de terceiro — PDF, imagem, texto de banca, modelo —
entra no manifesto antes de entrar no repositório. É o registro por item
referenciado pela cláusula 5 do `LICENSE` (ADR-0007).

Valores de `licenseStatus` em uso:

- `project-generated`: criado pelo próprio projeto, como o fixture sintético.
- `not-verified`: fornecido por terceiro ou pelo responsável, sem licença
  conferida. Autoriza apenas teste local.

`allowedForProductContent: true` exige `licenseStatus` verificado e diferente de
`not-verified`. Enquanto a licença não é conferida, o item fica com
`allowedForTesting: true` e `allowedForProductContent: false`, o que barra
catálogo, home, screenshots de produto e produção.

`test/fixture_license_policy_test.dart` falha se faltar campo, se o `id`
repetir, se o `document.path` não existir, se o `sha256` não tiver 64 dígitos
hexadecimais, se um item liberado para produto estiver `not-verified` ou se
houver arquivo `.backup` em `test/fixtures/`. A duplicata é desnecessária: o
original está no Git e o hash do manifesto cobre a integridade.

O PDF pode ser regenerado com Python e ReportLab 5.0.1:

```sh
python3 -m pip install reportlab==5.0.1
python3 test/fixtures/generate_synthetic_two_column_exam.py
```

`vunesp_2024_pm_sp.pdf` é o benchmark real fornecido pelo responsável pelo
projeto. O teste valida extração e estrutura (32 páginas, 80 questões e ordem)
e o arquivo não deve ser incluído no catálogo ou em telas de produto. O teste
também verifica a origem das quatro questões com alternativas visuais, a
continuação de questões entre páginas, IDs de mídia únicos vinculados às
questões e às páginas fonte, persistência desses vínculos e renderização JPEG
seletiva das páginas de revisão e da tabela periódica de referência.
As prévias têm 1200 px no máximo e o processamento limita o conjunto a 12 MiB;
se o limite for alcançado, o importador mantém as páginas concluídas e informa
que algumas páginas ficaram sem prévia.

O caderno do ENEM 2025 (Prova Verificada, dia 1, caderno 1, versão azul) fica na
raiz do repositório como `2025_PV_impresso_D1_CD1.pdf` e está no `.gitignore`:
`test/enem_2025_import_test.dart` só roda na máquina que tem o arquivo e é
pulado nas demais. Ele é o benchmark das provas de duas colunas com marcação
quebrada ("Quest ão 04"), marca d'água repetida e enunciado impresso na coluna
vizinha; as 90 questões são checadas em ordem, com no máximo 12 para revisar.
Nenhum dos três PDFs acima entra no catálogo nem em telas de produto. O caderno
do ENEM fica fora do Git e, por isso, fora do manifesto; se um dia for
versionado, precisa ser registrado como `user-provided-benchmark`,
`licenseStatus: not-verified` e `allowedForProductContent: false`.
