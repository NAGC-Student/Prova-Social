import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/answer_key_parser.dart';
import 'package:prova_social/core/import/question_parser.dart';

/// The shapes the main Brazilian boards actually print, kept as text because
/// the parser is what changes from one banca to another.
///
/// Each case carries the instructions page, the marker of the board, the
/// alternatives and the printed gabarito, and is read exactly the way the
/// import screen reads it: parse the caderno, then apply the key.
({List<ImportedQuestion> questions, AnswerKeyApplication key}) readCaderno(
  String source,
) {
  final questions = const QuestionParser().parse(source);
  const parser = AnswerKeyParser();
  return (
    questions: questions,
    key: parser.apply(parser.parseText(source), questions),
  );
}

void main() {
  test('VUNESP: instruções numeradas, QUESTÃO 0N e alternativas (A)-(D)', () {
    final exam = readCaderno('''
PREFEITURA DE SÃO PAULO — CONCURSO PÚBLICO
INSTRUÇÕES GERAIS
Leia com atenção as instruções a seguir.
1. Esta prova contém 3 questões objetivas.
2. O tempo de duração da prova é de três horas.
3. Não é permitido o uso de celular durante a aplicação.

QUESTÃO 01
Qual é a capital do estado de São Paulo?
(A) Campinas.
(B) São Paulo.
(C) Santos.
(D) Sorocaba.

QUESTÃO 02
O Rio Tietê atravessa a cidade e nasce em
(A) Salesópolis.
(B) Ribeirão Preto.
(C) Presidente Prudente.
(D) Bauru.

QUESTÃO 03
Assinale a alternativa que completa corretamente a frase: “O servidor,
____ chegou tarde, justificou a ausência.”
(A) que.
(B) quem.
(C) cujo.
(D) qual.

GABARITO OFICIAL
01 B
02 A
03 A
''');

    expect(exam.questions.map((question) => question.number), [1, 2, 3]);
    expect(exam.questions.every((q) => q.options.length == 4), isTrue);
    expect(exam.questions.first.statement, contains('capital'));
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [1, 0, 0]);
  });

  test('CEBRASPE: itens julgados com caixa de resposta e gabarito C/E', () {
    final exam = readCaderno('''
DEFENSORIA PÚBLICA DO ESTADO — CARGO 12
Julgue os itens subsequentes, relativos à organização da Defensoria.

1. ( ) A Defensoria é órgão essencial à função jurisdicional do Estado.
2. ( ) O Defensor-Geral é escolhido em lista tríplice.
3. ( ) O assistido pode requerer a substituição do defensor público.

GABARITO
1-C
2-E
3-C
''');

    expect(exam.questions, hasLength(3));
    expect(
      exam.questions.every((q) => q.format == QuestionFormat.trueFalse),
      isTrue,
    );
    expect(exam.questions.first.options, ['CERTO', 'ERRADO']);
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [0, 1, 0]);
  });

  test('FGV: marcador “Questão 21” com cinco alternativas e texto longo', () {
    final exam = readCaderno('''
Prova Discursiva-Objetiva — Auditor Fiscal
Questão 21
No trecho “a receita caiu, mas a fiscalização aumentou”, a conjunção “mas”
introduz uma ideia de
A) oposição.
B) condição.
C) conclusão.
D) proporção.
E) finalidade.

Questão 22
Assinale a alternativa em que o verbo emprega o futuro do pretérito.
A) Cumprirá o prazo.
B) Cumpriria o prazo.
C) Cumpre o prazo.
D) Cumpria o prazo.
E) Cumprira o prazo.

Questão 23
O regime jurídico único dos servidores municipais decorre de
A) lei federal.
B) lei municipal.
C) decreto do Prefeito.
D) contrato individual.
E) decisão judicial.

GABARITO
21-A
22-B
23-B
''');

    expect(exam.questions.map((question) => question.number), [21, 22, 23]);
    expect(exam.questions.first.options.first, 'oposição.');
    expect(exam.questions.first.options, hasLength(5));
    expect(exam.key.applied, 3);
    expect(exam.questions.last.correctIndex, 1);
    expect(exam.questions.map((question) => question.correctIndex), [0, 1, 1]);
  });

  test('FCC: comando negativo e alternativas entre parênteses', () {
    final exam = readCaderno('''
Tribunal de Justiça de São Paulo — Escrevente
Questão 15
Assinale a alternativa em que o uso da crase está INCORRETO.
(A) Voltou à casa da avó.
(B) Referiu-se àquela matéria.
(C) Entregou o relatório à diretoria.
(D) Começou à trabalhar cedo.
(E) Deu o prêmio à vencedora.

Questão 16
Está corretamente empregado o emprego do “porquê” em
(A) Perguntei por que ele faltou.
(B) Não sei o porquê da atraso.
(C) Chegou tarde, porque o ônibus quebrou.
(D) Perguntou o porque ninguém avisou.
(E) Foi embora sem explicá-lo porque.

Questão 17
A concordância observa a norma-padrão em
(A) Fazem dez anos que ele saiu.
(B) Haviam muitos candidatos na sala.
(C) Existem provas suficientes no autos.
(D) Deve haver recursos ainda nesta fase.
(E) Bastavam-lhe as palavras do chefe.

GABARITO
15-D
16-C
17-D
''');

    expect(exam.questions, hasLength(3));
    expect(exam.questions.first.options, hasLength(5));
    expect(exam.questions.first.statement, contains('INCORRETO'));
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [3, 2, 3]);
  });

  test('IBFC: prova com tipo e questões numeradas em dois algarismos', () {
    final exam = readCaderno('''
PREFEITURA DE CURITIBA — PROVA TIPO 1
Questão 31
O princípio pelo qual a administração pública somente faz o que a lei autoriza
é o da
(A) supremacia do interesse público.
(B) legalidade.
(C) impessoalidade.
(D) eficiência.

Questão 32
A revogação do ato administrativo decorre de
(A) ilegalidade.
(B) conveniência e oportunidade.
(C) vício de competência.
(D) fraude.

Questão 33
Compete à União explorar
(A) o serviço local de gás canalizado.
(B) o transporte rodoviário intermunicipal.
(C) o correio e o telégrafo.
(D) a coleta de lixo domiciliar.

GABARITO
31-B
32-B
33-C
''');

    expect(exam.questions.map((question) => question.number), [31, 32, 33]);
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [1, 1, 2]);
  });

  test('FUNDATEC: alternativas em letras minúsculas', () {
    final exam = readCaderno('''
Câmara de Vereadores — Nível Médio
Questão 5
Constitui ato de improbidade que causa prejuízo ao erário:
a) fraudar a execução de um contrato.
b) receber salário por cargo não exercido.
c) frustrar o caráter competitivo de licitação.
d) doar bens públicos a entidade sem fins lucrativos.
e) utilizar bens móveis em obra particular.

Questão 6
A licitação será dispensável quando
a) houver greve na categoria.
b) for urgente a contratação, em caso de calamidade pública.
c) o objeto for de baixo valor e dispensado por lei.
d) houver fornecedor único para o objeto.
e) a administração revogar o edital.

Questão 7
É vedado ao servidor público municipal
a) recusar fé a documentos públicos.
b) exercer atribuições com zelo e diligência.
c) manter conduta ilibada na repartição.
d) comunicar aos superiores irregularidades.
e) apresentar-se pontualmente ao trabalho.

GABARITO
5-A
6-C
7-A
''');

    expect(exam.questions.map((question) => question.number), [5, 6, 7]);
    expect(exam.questions.first.options.first, startsWith('fraudar'));
    expect(exam.questions.first.options, hasLength(5));
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [0, 2, 0]);
  });

  test('AOCP: rótulo de alternativa com traço “A - alternativa”', () {
    final exam = readCaderno('''
Empresa Pública — Técnico de Enfermagem
Questão 12
O descarte de material perfurocortante deve ocorrer em
A - caixa de papelão.
B - coletor resistente à perfuração.
C - saco branco leitoso.
D - lixo doméstico comum.

Questão 13
A esterilização de artigos médico-hospitalares por calor é feita em
A - autoclave.
B - geladeira.
C - estufa de secagem apenas.
D - lavadora ultrassônica apenas.

Questão 14
A higiene das mãos antes do procedimento
A - dispensa o uso de água.
B - reduz a flora transitória da pele.
C - deve durar menos de cinco segundos.
D - substitui o uso de luvas.

GABARITO
12-B
13-A
14-B
''');

    expect(exam.questions.map((question) => question.number), [12, 13, 14]);
    expect(exam.questions.first.options, [
      'caixa de papelão.',
      'coletor resistente à perfuração.',
      'saco branco leitoso.',
      'lixo doméstico comum.',
    ]);
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [1, 0, 1]);
  });

  test('QUADRIX: itens de julgamento com “C ( ) E ( )”', () {
    final exam = readCaderno('''
Prefeitura — Agente Comunitário de Saúde
Julgue os itens que se seguem, acerca das atribuições do agente.
Questão 31
O agente deve realizar visitas domiciliares periódicas. C ( ) E ( )
Questão 32
A cadastração de gestantes é atribuição exclusiva do médico da equipe.
C ( ) E ( )
Questão 33
O agente comunitário participa do processo de Vigilância em Saúde.
C ( ) E ( )

GABARITO
31-C
32-E
33-C
''');

    expect(exam.questions, hasLength(3));
    expect(
      exam.questions.every(
        (question) => question.format == QuestionFormat.trueFalse,
      ),
      isTrue,
    );
    expect(exam.questions.first.statement, contains('visitas domiciliares'));
    expect(exam.questions.first.statement, isNot(contains('C ( )')));
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [0, 1, 0]);
  });

  test('CONSULPLAN e IBADE: marcador com traço após o número', () {
    final exam = readCaderno('''
PROCESSO SELETIVO SIMPLIFICADO
QUESTÃO 01 - O ato administrativo que a Administração reavalia quanto à
conveniência e à oportunidade é o de
(A) anulação.
(B) revogação.
(C) convalidação.
(D) sustação.

QUESTÃO 02 - Controle exercido pelo Tribunal de Contas é denominado
(A) interno.
(B) externo.
(C) hierárquico.
(D) corretivo.

QUESTÃO 03 - A modalidade de licitação para contratos de engenharia de alto
valor é o
(A) convite.
(B) pregão.
(C) concurso.
(D) regime diferenciado.

GABARITO
01-B
02-B
03-D
''');

    expect(exam.questions.map((question) => question.number), [1, 2, 3]);
    expect(exam.questions.first.statement, isNot(startsWith('- ')));
    expect(exam.key.applied, 3);
    expect(exam.questions.map((question) => question.correctIndex), [1, 1, 3]);
  });

  test('ENEM: marcador em linha própria e alternativas sem pontuação', () {
    final exam = readCaderno('''
QUESTÕES OBJETIVAS
Este caderno contém 3 questões.

Questão 01
Ao abordar a celebração do Halloween, esse texto tem por objetivo
A denunciar a violência contra crianças indígenas.
B descrever costumes tradicionais desses povos.
C valorizar as vestimentas dos povos originários.
D criticar a exploração indevida de elementos da cultura indígena.
E sugerir ações de combate ao preconceito contra os povos originários.

Questão 02
Nesse texto, ao discorrer sobre a relevância da filosofia, a autora tem por
objetivo
A criticá-la pela restrição temática.
B vinculá-la ao universo acadêmico.
C afastá-la da abordagem socrática.
D aproximá-la dos problemas sociais.
E responsabilizá-la pela pobreza humana.

Questão 03
Nesse poema, o eu lírico ressalta a
A potência dos astros celestes.
B origem das plantas e dos animais.
C importância do apego à terra natal.
D relação entre seres humanos e natureza.
E conexão entre o tempo real e o tempo imaginário.
''');

    expect(exam.questions.map((question) => question.number), [1, 2, 3]);
    expect(exam.questions.every((q) => q.options.length == 5), isTrue);
    expect(exam.questions.first.options.first, startsWith('denunciar'));
    expect(exam.questions.first.statement, contains('Halloween'));
  });
}
