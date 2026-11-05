---
tipo: area
area: experiência e criação de prova
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Fluxo de Entrada e Criação — rascunho de conversa

> **Estado:** proposta registrada a partir da conversa com o responsável. O
> restante deste arquivo continua rascunho e não autoriza implementar código. As
> decisões do scanner foram consolidadas e fechadas em [[Importação e OCR]];
> detalhes ainda abertos continuam sinalizados.

## Estado verificado do scanner (2026-11-04)

O scanner foi auditado e sua especificação foi fechada em
[[Importação e OCR]]. O que existe hoje:

- **Implementado:** PDF com texto nativo e OCR seletivo no mobile, ordenação de
  colunas, remoção de mobília, parser de formatos, gabarito impresso, quality
  gate `good`/`review`/`retry`, revisão com página original e início de tentativa
  privada. JSON pré-estruturado e criação manual também existem.
- **Parcial:** confiança é heurística, não calibrada; a UI ainda mostra
  porcentagem; questões visuais/fórmulas não são compreendidas; OCR nativo não
  foi validado em aparelho.
- **Ausente:** câmera/galeria, fila de feedback, exportação/retorno do feedback
  e publicação de discursivas. O rascunho objetivo sem gabarito pode ser salvo e
  resolvido, mas não publicado, conforme a decisão já registrada.
- **Divergência a corrigir:** a publicação atual exige alternativas e gabarito
  em todas as questões, contrariando a decisão de aceitar discursivas e
  rascunho sem chave.

Critérios de aceite e fases P1.0–P1.3 estão em [[Importação e OCR]]. Nada foi
alterado no código nesta rodada.

## Nome e proposta

- Nome de trabalho sugerido pelo responsável: **Solucionar**.
- A marca ainda não foi renomeada nem aprovada definitivamente. Disponibilidade,
  conflitos e decisão final continuam pendentes.
- Descrição em elaboração: “um app de digitalização e rede social para provas de
  concursos, para ajudar pessoas a estudar de forma mais rápida, prática e
  dinâmica.”
- A intenção social não deve tirar a questão e a prova do centro do produto.

## Sequência imaginada para a primeira abertura

1. Ao tocar no ícone, mostrar o símbolo da marca com um elemento/raio verde em
   rotação, enquanto a inicialização real ocorre. Isso substitui o vazio/tela
   preta; não deve fingir carregamento depois que a inicialização terminou.
2. Fazer uma transição curta do símbolo/nome “Solucionar” para o canto superior
   esquerdo e, então, apresentar o que o app faz.
3. Na apresentação, explicar o produto e mostrar o fluxo de importar, revisar,
   resolver e acompanhar resultados.
4. **Decisão confirmada:** exibir a apresentação apenas no primeiro uso. A
   pessoa pode pulá-la; ao terminar ou pular, ela não reaparece
   automaticamente.

## Tela de criação

Ao entrar em **Criação**, oferecer somente três caminhos na primeira versão:

1. **Importar PDF para digitalização**
2. **Importar JSON pré-estruturado**
3. **Criar prova manualmente** usando o sistema de questões

**Escopo por fase:** câmera, galeria e múltiplas imagens entram em P1.1, com
recorte e ordenação; não fazem parte do caminho atual. A tela não deve exibir
esses caminhos antes de eles funcionarem. Ver [[Importação e OCR]].

A busca existente foi considerada boa pelo responsável; a intenção é mantê-la
enquanto se reestrutura o restante. Isso não substitui testes de regressão.

## Prova e gabarito

- Na entrada de uma prova objetiva, oferecer dois passos/campos distintos:
  **Enviar prova** e **Enviar gabarito**.
- O gabarito pertence à prova, mas deve ser importado e conferido como material
  separado, ligado às questões correspondentes. A posição/número visível da
  questão pode ajudar a correspondência, mas a estrutura final deve possuir
  vínculo estável; não depender só da posição visual se as questões forem
  reordenadas.
- O gabarito não deve ser mesclado no texto público da prova: preservar o
  princípio de armazenamento e entrega privada de respostas corretas.
- O gabarito importado também pode conter falhas. Deve haver conferência e
  correção humana; o sistema não completa lacunas por inferência.
- **Decisão confirmada:** uma prova objetiva sem gabarito confirmado pode ser
  salva e resolvida, mas não recebe pontuação até a confirmação do gabarito.
  Questões sem chave confirmada ficam identificadas como não corrigíveis e não
  podem ser contabilizadas como erradas.
- **Decisão confirmada:** sem gabarito confirmado, a prova pode permanecer como
  rascunho privado, mas não pode ser publicada. O gabarito confirmado continua
  privado e serve à correção; não é exibido como parte pública da prova.
- Provas discursivas e provas sem chave confirmada continuam representáveis,
  conforme os princípios já registrados em `AGENTS.md`.

## Importação de PDF: progresso verdadeiro

- O processamento deve ocorrer sem bloquear a interface.
- Mostrar atualizações concretas à medida que o trabalho acontece, como páginas
  processadas e questões encontradas, em vez de um spinner sem informação.
- Só anunciar uma folha como lida ou questão como encontrada depois que o
  respectivo passo realmente terminou.
- A pessoa deve conseguir entender se o sistema ainda trabalha, se precisa de
  revisão ou se houve uma falha recuperável.
- O mecanismo atual e as operações que podem rodar em segundo plano precisam
  ser auditados antes de fixar detalhes técnicos.

## Metadados pretendidos

Após ler o arquivo, sugerir os dados reconhecidos e permitir que a pessoa
confirme/edite. A tela imaginada contém:

- **Título:** aproveitar o nome do concurso/prova, preferencialmente obtido do
  conteúdo; nome do arquivo pode ajudar como fallback, mas a regra final está
  em aberto.
- **Banca:** por exemplo, Vunesp ou FUVEST; campo próprio.
- **Concurso/instituição:** por exemplo, EPCAR ou Barro Branco; campo próprio.
- **Disciplina/tópico:** classificação acadêmica separada (por exemplo,
  Matemática/Álgebra).
- **Temas:** etiquetas de múltipla seleção, independentes de banca, concurso e
  disciplina. **Lista inicial confirmada:** Militar, Vestibular, ENEM, Concursos
  públicos, Carreiras policiais, Carreiras jurídicas, Carreiras fiscais,
  Carreiras administrativas, Educação, Saúde, Tecnologia, Engenharia, Ciências
  exatas, Ciências humanas, Ciências da natureza, Língua portuguesa, Línguas
  estrangeiras, Matemática, Raciocínio lógico, Informática, Conhecimentos
  gerais, Atualidades, Redação, Preparação acadêmica, Formação profissional,
  Olimpíadas científicas, Certificações profissionais, Pós-graduação e Pesquisa
  científica. A lista deve permanecer ampla e não misturar nomes de concursos,
  instituições ou bancas como etiquetas de tema. **Decisão confirmada:** novos
  temas podem ser sugeridos por usuários, mas só entram no catálogo oficial após
  revisão e aprovação da equipe. Sinônimos ou variações de um tema existente
  viram aliases do tema canônico, sem criar uma opção duplicada no seletor.
- **Fonte/procedência:** sempre identificar o tipo da fonte. **Decisão
  confirmada:** URL obrigatória para classificar como fonte oficial; opcional
  para envio comunitário ou fonte não verificada.
- **Ano:** sugerir automaticamente quando estiver indicado no documento.
- **Duração:** quando o documento indicar o tempo oficial (por exemplo, três
  horas), preencher automaticamente esse valor; sem indicação no arquivo, não
  inventar uma duração. **Decisão confirmada:** antes de iniciar, pedir que a
  pessoa configure o tempo (ou escolha fazer sem cronômetro).

**Decisão confirmada:** banca, concurso/instituição, disciplina/tópico e temas
são dimensões separadas; temas são multisseleção. Valores extraídos
automaticamente são sugestões, não fatos garantidos, e o responsável pela
importação deve poder revisar a atribuição.

## Revisão das questões

- Listar questões reconhecidas e destacar as que não puderam ser lidas ou
  estruturadas com confiança.
- Para uma questão que precise de conferência, oferecer acesso à imagem original
  da página da prova. A pessoa pode abrir a página e comparar o enunciado,
  fórmulas, figuras e alternativas com o que foi reconhecido.
- Ao editar a questão, manter a página original facilmente acessível enquanto a
  pessoa digita, inclusive quando o teclado virtual estiver aberto. Ela deve
  conseguir consultar e copiar manualmente o que está impresso. **Decisão
  confirmada:** no celular, o visualizador da página fica acima do editor e pode
  ser recolhido; no desktop, página e editor ficam lado a lado.
- **Decisão da conversa:** salvar uma correção manual confirma a questão como
  válida e avança para a próxima; não exigir um segundo toque em **Válida**.
- Depois da conferência, mostrar duas ações claras: **Válida** e **Inválida**.
  Válida confirma a questão revisada e segue para a próxima. Inválida também
  segue para a próxima, mas registra o caso na fila de feedback e não inclui a
  questão na prova que a pessoa vai resolver. O envio do relatório requer
  confirmação explícita, separada da decisão de validade.
- Questões inválidas ou não reconhecidas não são apagadas: ficam associadas à
  importação para análise/correção posterior.
- **Decisão confirmada sobre não ser fazível:** se o scanner não encontrar a
  própria questão, não encontrar alternativas em uma questão objetiva, não
  recuperar uma fórmula necessária ou não recuperar uma imagem necessária, a
  questão não pode ser resolvida e fica fora da prova para correção/feedback.
  Pequenos erros de leitura do texto que a pessoa consiga corrigir manualmente
  não tornam a questão não fazível.
- **Decisão para a primeira versão:** não mostrar porcentagem nem excluir uma
  questão apenas por score numérico. Os scores atuais são heurísticas não
  calibradas; usar sinais estruturais verificáveis para classificar como
  **fazível**, **corrigível** ou **não fazível**. Se não for possível decidir
  estruturalmente se uma imagem ou fórmula é essencial e foi recuperada, pedir
  revisão humana em vez de excluir automaticamente.
- Validar os critérios com documentos de ground truth autorizado antes de
  automatizar a classificação estrutural; os limiares internos atuais não são
  evidência suficiente de confiança probabilística.
- A prova pode ser iniciada com as questões válidas; questões em correção ficam
  fora daquela tentativa. **Decisão confirmada:** mostrar o total de questões
  válidas para resolver e, em separado, quantas ficaram fora da prova para
  revisão. A exclusão não pode impedir o início nem entrar na pontuação.

## Problemas de digitalização e feedback

O responsável quer uma área de **Feedbacks** visível apenas na conta de dono do
aplicativo, reunindo questões que foram marcadas como inválidas e casos que o
sistema classificou como não fazíveis por requisitos estruturais ausentes.
Cada item deve permitir entender o que falhou e orientar correção do parser.

**Estado verificado:** o contrato JSON, a retenção e o ciclo de retorno estão
especificados, mas a fila, o painel, o envio e o recibo anônimo **não existem no
código**. A rotina de triagem, regressão e retreinamento está fechada em
[[Importação e OCR#Rotina de retreinamento e regressão]].

- A proposta atual é uma fila de feedbacks dentro da conta do dono, em vez de
  depender apenas de e-mail. **Decisão confirmada:** cada feedback fica na área
  interna restrita ao dono; chega um e-mail de aviso com link seguro, sem incluir
  o conteúdo da questão na mensagem.
- **Pacote confirmado para envio após consentimento explícito:** tipo de falha,
  imagem da página inteira onde ocorreu, questão inteira, texto extraído,
  indicação de se houve tentativa de correção manual e o texto corrigido quando
  houver. A imagem deve registrar o que o scanner mostrou, para que a equipe
  consiga reproduzir e corrigir o problema. Não enviar o PDF inteiro, dados de
  conta nem respostas da tentativa por padrão; respeitar direitos de
  redistribuição do conteúdo.
- Se a pessoa não autorizar o envio da imagem da página, oferecer envio
  separado de texto e metadados; essa opção também exige confirmação explícita.
- **Decisão confirmada:** o feedback e sua exportação JSON são anônimos por
  padrão; não incluir identidade ou ID da conta de quem enviou.
- **Decisão confirmada:** exportar um JSON anônimo acompanhado pelas imagens de
  página consentidas como arquivos separados; o JSON referencia cada imagem e
  inclui tipo de falha, conteúdo da questão, texto extraído e eventual tentativa
  de correção manual. Não embutir os arquivos de imagem dentro do JSON.
- **Contrato de dados escolhido para a primeira versão:** JSON versionado com
  `schema_version`, identificador aleatório do feedback, data UTC, versões do
  app/PARSER/OCR, tipo da falha, número/páginas/posição da questão, texto
  extraído da página, estrutura integral da questão, correção manual (se houver),
  valores de confiança com seus produtores identificados e referências às
  imagens anexas. O score heurístico do PARSER nunca deve ser rotulado como
  probabilidade. A especificação técnica inicial e um exemplo estão em
  [[Importação e OCR]].
- Incluir no JSON somente dados aprovados pela pessoa no consentimento de envio.
  Não incluir nome do arquivo, PDF completo, respostas da tentativa, identidade
  ou ID de conta. A página original completa é um anexo separado, enviada só
  após consentimento explícito e respeitando direitos de uso.
- **Destino escolhido em princípio:** Supabase para metadados e recortes
  privados. Antes de implementar, auditar o schema e o armazenamento já
  configurado; não presumir a existência de tabela ou bucket. O acesso deve
  permanecer restrito à conta autorizada do dono. **Decisão confirmada sobre
  retenção:** manter até o dono marcar como resolvido; apagar 90 dias depois.
- O acesso à fila é privilegiado e requer controle de acesso; não pode aparecer
  para usuários comuns.
- **Ciclo de correção confirmado:** depois de implementar uma correção para o
  problema reportado, avisar a pessoa e pedir que tente digitalizar novamente.
  Se a nova tentativa funcionar, encerrar o feedback como resolvido; se não,
  permitir que o caso continue para investigação.

## Três destinos após a revisão

- **Iniciar prova agora:** começar uma tentativa com as questões válidas.
- **Salvar na biblioteca:** guardar a prova localmente e voltar à tela inicial;
  a prova deve aparecer na biblioteca e ser destacada como nova.
- **Publicar:** se a pessoa estiver autenticada, seguir para a etapa de
  publicação; se não, solicitar login/autenticação e retomar a intenção.

“Salvar na biblioteca” e “publicar” são destinos diferentes. Publicar envolve
procedência, permissão para compartilhar, revisão e confirmação final; os
detalhes serão definidos antes de qualquer implementação.

## Iniciar e resolver uma prova

1. Ao escolher **Iniciar prova agora**, o símbolo/nome Solucionar faz uma
   transição para o topo da tela e a experiência muda para Focus Mode, sem a
   navegação social concorrendo com a resolução.
2. No topo, mostrar a questão atual e o total (por exemplo, “Questão 1 de N”).
   As alternativas aparecem como opções selecionáveis e a escolha fica
   registrada na tentativa.
3. Um botão **Próxima questão**, em verde, avança para a seguinte.
4. A opção **Não sei** marca a questão para revisão e a inclui na lista de
   questões que a pessoa quer refazer. Ela não deve ser apresentada como erro
   confirmado se não houve resposta corrigida; relatório e filtros devem
   distinguir “não sei” de resposta errada.
5. **Decisão da conversa:** na última questão, o botão de avanço vira
   **Finalizar prova**. A pessoa pode finalizar mesmo com questões em branco; o
   app avisa quantas ficaram sem resposta, mas não bloqueia a conclusão. Ao
   finalizar, perguntar se questões deixadas sem resposta também entram na prova
   de erros; “Não sei” já entra por padrão.
6. Se o tempo total da prova estiver disponível/configurado, exibir uma
   contagem regressiva no canto superior direito. Ao tocar, recolher o número e
   mostrar um relógio circular/indicador tipo fio, cujo preenchimento diminui
   conforme o tempo passa. Ao acabar, o indicador fica vazio.
   **Decisão da conversa:** quando o tempo zerar, finalizar a tentativa
   automaticamente e mostrar o resultado. O tempo oficial do PDF é preenchido
   automaticamente; se faltar, a pessoa configura um limite ou escolhe sem
   cronômetro. **Decisão confirmada:** antes de iniciar, a pessoa escolhe se
   aquela tentativa permite pausar o cronômetro.
7. A prova continua sendo uma tentativa local para visitante ou usuário
   autenticado. **Decisão confirmada:** cada resposta é salva no aparelho
   imediatamente, sem depender de login ou rede. Ao retomar, voltar à questão e
   ao estado salvos.
8. Uma conta permite solicitar publicação e backup/sincronização entre
   aparelhos, respeitando o estado local já existente e a política de
   autenticação.
9. **Decisão confirmada:** apagar uma tentativa exige confirmação e remove suas
   respostas do aparelho e, quando sincronizadas, da conta. A prova salva na
   Biblioteca é independente e permanece. Uma exclusão feita offline não pode
   fazer as respostas reaparecerem quando a sincronização voltar. A prova de
   erros gerada permanece como material de estudo independente.

## Finalização e resultado

### Hierarquia da tela

1. Na parte superior central, destacar o total de questões acertadas e a
   quantidade da prova (ex.: “X de Y corretas”), de forma visualmente
   proeminente e sem texto que envergonhe a pessoa.
2. A cor desejada representa o resultado: menos da metade em vermelho,
   exatamente metade em laranja e mais da metade em verde. Classificar pelo
   percentual exato, sem arredondar para escolher a cor; com quantidade ímpar
   de questões corrigíveis, pode não existir resultado exatamente em 50%.
   **Decisão confirmada:** o denominador contém todas as questões válidas com
   gabarito confirmado. Em branco e “Não sei” não ganham ponto, mas continuam
   identificados separadamente e não são rotulados como respostas erradas.
   Questões sem gabarito confirmado, inválidas ou anuladas sem tratamento
   oficial definido ficam fora da pontuação.
3. Abaixo, mostrar desempenho por área/tema (por exemplo, matemática e
   português), com contagens compreensíveis de acerto/erro.
4. Disponibilizar a ação **Revisar prova** — preferida a “Ver erros” para evitar
   um tom punitivo. Essa tela pode mostrar a resposta escolhida, gabarito
   confirmado e explicação disponível para cada questão.
5. Resultado e revisão também devem distinguir erro, em branco, “Não sei”,
   anulada e não corrigível. Não exibir gabarito como oficial se sua origem não
   estiver confirmada.

As áreas só podem ser mostradas quando a classificação estiver associada à
questão com confiabilidade suficiente; não deduzir assunto pela aparência do
texto. Sem disciplina confirmada, mostrar os dados gerais sem inventar
categorização.

### Fluxo de “Revisar prova”

- A revisão terá três filtros/abas no topo, com símbolos além das cores:
  **acertadas** (check verde), **erradas** (X vermelho) e **em branco**
  (círculo branco). O significado não depende apenas da cor.
- Ao entrar em uma questão acertada, usar a mesma apresentação da questão da
  prova e destacar em verde o resultado correto. A pessoa percorre as questões
  desse filtro em sequência.
- O filtro de erradas mostra as questões respondidas incorretamente. O filtro
  de em branco reúne questões sem resposta e questões marcadas **Não sei**,
  conforme decisão confirmada. Dentro da aba, cada item mantém seu rótulo de
  estado próprio para não confundir “Não sei” com uma questão deixada sem ação.
- Nos itens errados e em branco, oferecer **Gerar explicação** e **Perguntar
  para pessoas**. A geração não deve mencionar IA no texto do botão.
- **Procedência da explicação:** identificar claramente se é uma **resposta
  oficial** (com o nome da fonte), uma **resposta de uma pessoa** ou uma
  **resposta gerada por IA**. Não apresentar conteúdo gerado como se tivesse
  sido escrito por uma pessoa ou publicado por uma fonte oficial; deixar
  explícito qual parte foi gerada e qual parte foi contribuição humana.
- Antes da primeira geração, explicar que a função exige capacidade local do
  aparelho e pode não ser recomendada em dispositivos incompatíveis. A pessoa
  pode escolher gerar explicações ou usar somente a ajuda de outras pessoas;
  poder apenas fechar a revisão encerra o fluxo sem obrigar nenhuma escolha.
- **Perguntar para pessoas** abre um painel de composição curto, parecido com
  uma publicação, para pedir ajuda sobre aquela questão. A dúvida fica ligada
  à questão; outras pessoas podem encontrá-la, ler as respostas e contribuir,
  formando uma discussão reutilizável em vez de uma mensagem privada isolada.
- Cada questão tem uma URL própria para compartilhar; prova e perfil também
  terão URLs próprias. Uma pergunta/resposta compartilhada direciona à questão
  e à discussão relacionada. Compartilhar uma questão não publica a prova
  inteira nem altera seu estado de publicação. **Decisão confirmada:** a questão
  herda a privacidade e as permissões da prova de origem; não pode ser publicada
  separadamente para contornar essa privacidade.
- O link abre a página web da questão ou a mesma tela no app instalado. A
  intenção é que a pessoa consiga visualizar o conteúdo público compartilhado
  sem login e autentique-se para responder ou realizar outras ações sociais.
  Essa interpretação refina a anotação anterior de autenticação obrigatória
  para “usar” a área.
- **Decisão confirmada:** publicar uma dúvida ou resposta exige autenticação;
  qualquer pessoa logada pode responder. Antes de publicar a própria dúvida, a
  pessoa escolhe se aparece com sua conta ou como **anônima**. Anonimato é a
  forma de exibição para as outras pessoas; o vínculo autenticado é mantido
  internamente para reduzir abuso. **Decisão confirmada:** só a própria pessoa
  e moderadores autorizados podem consultar a identidade real por trás de uma
  publicação anônima.
- Para respostas que não possam ser enviadas, o comportamento desejado é
  mostrar **“Resposta não autorizada”** com os motivos (como **conduta não
  apropriada** ou **palavra não apropriada**) e permitir editar e tentar
  novamente sem limite. A resposta só é publicada depois de aprovada na
  verificação apropriada.
- **Correção de escopo:** PARSER é o scanner que digitaliza provas, valida as
  questões e normaliza os formatos em uma estrutura comum. Ele não deve ser
  tratado como o moderador de texto social nem como verificador de palavrões,
  conduta ou qualidade das respostas; não atribuir essa decisão ao PARSER.
- **Decisão confirmada:** respostas serão avaliadas por um classificador
  dedicado no servidor, separado do PARSER. Casos incertos vão para revisão
  humana e não são publicados antes da aprovação.
- **Decisão confirmada:** se a resposta for rejeitada e a pessoa discordar,
  ela pode solicitar revisão humana. A resposta continua não publicada até
  aprovação; editar e reenviar continuam sendo opções.
- **Decisão confirmada:** enquanto a revisão estiver pendente, o texto fica
  disponível à equipe responsável pela análise. Assim que houver decisão, o
  texto rejeitado é apagado; permanecem apenas o resultado e o motivo da
  decisão.
- **Decisão confirmada:** a fila de revisão é acessível ao dono do app e a
  moderadores designados. A identidade do autor fica oculta por padrão e só pode
  ser revelada quando necessária e por pessoa autorizada.
- **Decisão confirmada:** se a revisão humana aprovar a resposta, devolvê-la à
  pessoa para confirmação explícita antes de publicar. Se a revisão rejeitar,
  informar o motivo; a resposta permanece privada e pode ser corrigida e
  reenviada.
- **Decisão confirmada:** uma resposta aprovada que aguarda confirmação do autor
  expira após 7 dias sem confirmação; apagar o texto sem publicá-lo.
- **Decisão confirmada:** uma resposta publicada denunciada fica oculta
  temporariamente quando receber denúncias de três pessoas diferentes; a
  denúncia, por si só, não define a decisão final.
- Antes de chegar a três denúncias, mostrar junto à resposta o progresso
  **“1 de 3”** ou **“2 de 3”**. Denúncias repetidas da mesma conta não contam
  como pessoas distintas e não multiplicam o gatilho.
- **Decisão confirmada:** se a revisão da denúncia não confirmar violação,
  restaurar a resposta. Se confirmar, removê-la da visualização pública,
  informar o motivo ao autor e permitir que ele corrija e reenvie, passando
  novamente pela verificação.
- **Decisão confirmada:** a pessoa que denunciou recebe uma notificação quando
  a revisão termina, informando apenas o desfecho (por exemplo, se a resposta
  voltou a ficar visível), sem revelar dados privados do autor.
- Se a equipe concluir que não houve violação, além de restaurar a resposta,
  avisar as pessoas que fizeram uma pergunta sobre aquela questão de que a
  resposta voltou a ficar visível.
- **Motivos de denúncia escolhidos:** ofensa/assédio/discriminação; palavrão ou
  linguagem inadequada; spam/propaganda; conteúdo que não responde à pergunta
  ou não faz sentido; exposição de dados pessoais.
- **Decisão confirmada:** uma denúncia não confirmada não gera punição por si
  só, pois pode ter sido feita de boa-fé. Medidas devem se limitar a abuso
  deliberado e repetido.
- **Decisão confirmada:** após confirmação humana de abuso deliberado e repetido,
  restringir temporariamente a função de denúncia; se repetir, reavaliar e
  escalar a medida.
- **Decisão confirmada:** a restrição permanece até uma revisão humana decidir
  removê-la.
- Se o serviço estiver tecnicamente indisponível, manter o texto como rascunho
  não publicado e mostrar **“Não foi possível verificar; tente novamente”**;
  não tratar a falha como violação.
- Curtidas e avaliações **“Isso me ajudou”** são sinais positivos para avaliar
  a utilidade das respostas e o desempenho do classificador; denúncias são
  sinal de revisão, com ocultação ao atingir três pessoas distintas. Definir
  como combinar esses sinais e medir falsos positivos ainda exige avaliação.
- **Perguntas a responder** é uma aba própria e permanente da comunidade, para
  descobrir perguntas abertas e responder; não depende de já haver histórico.
- **Para você** é um feed contínuo de recomendações, principalmente de provas
  que a pessoa pode querer fazer. O algoritmo considera atividade e interesses
  observados. Exemplo: depois de fazer uma prova de Barro Branco, pode recomendar
  uma edição atualizada dela.
- Às vezes, entre recomendações de provas, **Para você** também pode mostrar
  uma pergunta sobre uma prova ou tema que a pessoa conhece, oferecendo a
  oportunidade de ajudar. Seguir alguém prioriza reciprocamente perguntas dessa
  pessoa nos feeds das duas pessoas; não transforma **Para você** em um feed
  composto apenas por publicações de quem a pessoa segue.
- Ao abrir uma pergunta, a pessoa vê uma conversa em comentários/mensagens
  ligada à questão. Quando envia uma resposta, ela aparece como uma mensagem
  nesse fio, onde outras pessoas também podem continuar ajudando.
- Ao tocar e segurar uma pergunta ou mensagem, pode escolher **Responder** ou
  **Referenciar**. **Responder** direciona a resposta àquela mensagem.
  **Referenciar** permite buscar/inserir um link para uma mensagem na própria
  composição; tocar no link leva diretamente à mensagem citada, como em um
  mensageiro.
- **Decisão confirmada:** respostas aparecem aninhadas sob a pergunta ou
  mensagem à qual respondem, mantendo visível a estrutura da conversa.
- Quem publicou a pergunta recebe avisos quando ela ganha respostas e pode
  escolher **Silenciar/Sair da questão** para parar notificações daquela
  conversa, sem excluir conteúdo nem perder acesso ao fio.
- Uma menção direta (`@nome`) ainda deve notificar a pessoa, mesmo que tenha
  silenciado a conversa.
- **Decisão confirmada:** cada notificação aparece na central do app e pode
  gerar um push no aparelho. Tocar no ícone de perfil/conta no canto superior
  direito abre um modal com uma seção **Notificações** e outra de
  **Configurações**. Uma notificação recente pode aparecer como aviso
  breve/pop-up.
- A seção de notificações mostra um contador de novidades e o histórico: avisos
  de novas provas, atividade de pessoas seguidas, respostas e menções. Quando
  houver mais de três, a lista fica recolhida e oferece **Ver todas as
  notificações**.
- **Decisão confirmada:** tocar em uma notificação marca-a como lida e abre o
  conteúdo relacionado (pergunta, resposta ou prova). O contador indica
  notificações não lidas. Uma não lida aparece destacada, com borda luminosa e
  efeito pulsante sutil; uma lida fica acinzentada/desaturada. A distinção deve
  continuar perceptível sem depender apenas de cor e a animação respeita a
  preferência de redução de movimento.
- **Decisão confirmada:** a pessoa pode escolher a ordem em que as seções
  **Notificações** e **Configurações** aparecem no modal.
- **Configurações iniciais aprovadas:**
  - canais independentes: push do aparelho e histórico/avisos na central do app;
  - categorias: respostas às minhas perguntas, respostas às minhas mensagens,
    menções, atividade de pessoas seguidas, provas novas/atualizadas
    relevantes, perguntas recomendadas para responder, pedidos para seguir meu
    perfil privado, decisões dos pedidos que enviei e itens de avatar
    desbloqueados;
  - período silencioso para push;
  - silenciar uma conversa individual sem apagar nem deixar de acessar o fio.
  Desativar push não apaga notificações já recebidas da central; menções
  continuam visíveis e não são suprimidas pelo silêncio de uma conversa.
- **Padrões confirmados:** iniciar ligadas todas as categorias listadas:
  respostas às minhas perguntas e mensagens, menções, atividade de pessoas
  seguidas, provas relacionadas, perguntas recomendadas e pedidos para seguir
  perfil privado/decisões dos pedidos que enviei e itens de avatar
  desbloqueados. Cada categoria pode ser desligada individualmente; futuras
  categorias não listadas começam desligadas até a pessoa ativá-las.
- Assim, a discussão pode desenvolver o raciocínio em conjunto e manter
  referências navegáveis para partes específicas da conversa. Hierarquia
  visual e edição/exclusão ainda precisam ser definidos.
- Ao fechar/finalizar a revisão, voltar à tela inicial. Na Biblioteca, mostrar
  a pontuação junto da prova concluída e, abaixo, uma área **Prova de revisão**
  com as questões erradas agrupadas pela prova original que a pessoa realizou.
  Essa especificação detalha e substitui, para esta superfície da Biblioteca, a
  proposta anterior de agrupamento apenas por concurso.

### Explicações por questão e IA local

- A intenção é que cada questão possa ter uma explicação própria e que, na
  revisão, um texto curto ajude a pessoa a entender o raciocínio e o motivo do
  erro.
- Ordem de confiança recomendada para avaliar: explicação oficial ou editorial
  fornecida com procedência; explicação comunitária revisada; por último,
  explicação gerada localmente e claramente identificada como sugestão.
- **Decisão confirmada:** a IA local será considerada um recurso opcional
  experimental, somente em aparelhos compatíveis; explicações oficiais e
  revisadas têm prioridade.
- Isso não é uma capacidade garantida: tamanho do modelo, RAM, armazenamento,
  velocidade, bateria, compatibilidade entre aparelhos e qualidade variam.
  “A menor possível que roda em qualquer celular” precisa de benchmark real;
  não prometer cobertura universal.
- Uma explicação gerada pode estar errada. Não deve alterar gabarito, corrigir
  tentativa nem substituir fonte oficial. Deve distinguir “explicação
  verificada” de “sugestão gerada” e permitir reportar erro.
- Se não houver explicação confiável ou geração local utilizável, a tela deve
  funcionar normalmente mostrando questão, resposta escolhida e gabarito
  confirmado, sem bloquear o estudo ou depender de IA paga.
- Definir se a explicação local é gerada sob demanda ou preparada offline;
  avaliar privacidade e desempenho antes de escolher.
- O rótulo visível da ação é **Gerar explicação**, sem afirmar no botão que foi
  usada IA. A natureza gerada, a procedência e os limites devem continuar
  transparentes em um texto informativo apropriado.

## Biblioteca e prova recém-salva

- **Salvar na biblioteca** volta à tela inicial e deixa a prova acessível na
  biblioteca local.
- A navegação inferior mantém: Início, Pesquisa, Criação, Biblioteca e Perfil.
- Ao salvar uma prova, a aba Biblioteca mostra um indicador de novidade e a
  prova mais recente aparece destacada visualmente, como um item ligeiramente
  elevado com realce.
- **Decisão confirmada:** o contador reúne todas as novidades da Biblioteca,
  incluindo provas recém-salvas e novas provas de revisão geradas a partir de
  erros; não representa o total de provas guardadas. Novidades ficam destacadas
  até serem vistas.
- **Decisão confirmada:** entrar na Biblioteca ou abrir um item não limpa o
  contador automaticamente. A pessoa usa **Marcar todas como vistas** para
  remover o contador e os destaques das novidades existentes.
- Uma prova salva localmente não é automaticamente pública. A biblioteca deve
  poder indicar se o item está somente no aparelho, sincronizado na conta ou
  publicado, conforme o estado real.

## Prova de revisão

- Manter questões para refazer em uma área da Biblioteca, agrupadas pela prova
  original em que a pessoa errou, em vez de juntar todas as questões em uma
  lista indistinta.
- As questões exibidas são as que a pessoa errou; estados em branco e “Não sei”
  continuam identificáveis. **Decisão confirmada:** “Não sei” também entra na
  prática de erros, sem ser pontuado como resposta errada. Ainda falta decidir
  por escolha da pessoa, no momento da finalização, se questões deixadas sem
  resposta também entram nessa prática.
- Questões erradas ficam no grupo da prova de origem. Quando a pessoa acerta
  uma questão numa revisão posterior, ela sai da seleção pendente daquele
  grupo; se errar novamente, permanece/retorna à seleção. **Decisão
  confirmada:** a questão acertada sai automaticamente da lista de erros
  pendentes, mas permanece em uma lista histórica de questões já resolvidas
  para revisão posterior. A pessoa pode indicar que ainda acha aquela questão
  difícil e quer revisá-la novamente.
- Questões erradas de provas diferentes do mesmo concurso permanecem em grupos
  separados pela prova de origem. Provas sem identificação confiável precisam
  de um grupo de origem honesto, sem inventar o concurso.
- A estrutura da lista de revisão está definida; ainda falta detalhar como
  tentativas repetidas são contabilizadas e exibidas ao longo do tempo.

## Conta, publicação e feedback do parser

- Sem conta, a pessoa ainda pode criar/importar localmente e resolver a prova.
- Com conta, a pessoa pode solicitar publicação e backup para trocar de
  aparelho; publicar continua sendo uma ação explícita, não consequência
  automática do login.
- O responsável quer que questões inválidas reportadas por usuários ajudem a
  corrigir e melhorar o **PARSER** (scanner de provas e normalizador de
  questões). A proposta da fila de feedback do dono está
  descrita acima; ainda não foi definida uma rotina de retreinamento.
- Não presumir que enviar conteúdo de usuário a um servidor ou usá-lo para
  treinar/ajustar modelos seja permitido sem aviso, consentimento e limites de
  retenção. Questões de terceiros podem ter direitos restritos; o feedback pode
  precisar limitar-se a sinais estruturais e correções anonimizadas.
- O app não deve enviar a tentativa, respostas, conta ou PDF completo por
  padrão. Definir o pacote mínimo, controles de acesso, acesso do dono e
  exportação JSON antes de ativar a fila remota.

## Navegação e biblioteca

Navegação inferior desejada:

1. Tela inicial
2. Pesquisa
3. Criação
4. Biblioteca
5. Perfil

Biblioteca deve ser centrada em provas registradas, com uma área para erros
cometidos. Ao salvar uma nova prova, mostrar confirmação e um indicador de
novidade na Biblioteca. O que significa “registrada” (salva localmente,
sincronizada ou publicada) precisa ser distinguido no rótulo/estado, para não
confundir a pessoa.

## Perfil

O perfil de outra pessoa apresenta:

- nome e `@usuário`;
- bio curta, se preenchida;
- avatar/personagem personalizável com muitas opções de aparência, permitindo
  representar a pessoa sem expor uma foto real;
- ações **Seguir/Deixar de seguir** e **Mensagem direta**;
- métricas de atividade, como provas publicadas, questões respondidas e
  respostas publicadas, além das métricas pessoais já propostas.

### Proposta de avatar colecionável

A proposta é usar um personagem que represente a trajetória de estudos,
concursos e conquistas, em vez de um boneco genérico com milhares de opções
desde o início. A pessoa monta o avatar por partes:

- rosto: formato, olhos, sobrancelhas, boca e expressões;
- cabelo: corte, estilo e cor;
- acessórios: por exemplo, óculos, fones e relógios;
- roupas: casuais e acadêmicas, com uniformes como uma categoria temática;
- itens especiais: livros, diplomas, chapéus e outros cosméticos.

**Catálogo inicial confirmado:** 5 modelos de rosto, 10 cortes de cabelo,
10 roupas, 15 acessórios e 5 chapéus temáticos. A coleção pode incluir temas
**acadêmico**, **estudioso**, **militar** e itens personalizados, sem deixar o
produto restrito à temática militar. **Direção visual confirmada:** pixel art
original, legível em tamanhos pequenos e sem aparência infantil. Os assets
ainda precisam ser criados ou ter licença compatível.

**Primeira versão aprovada para refinamento** — cinco desbloqueios cosméticos
por conquistas gerais reais:

| Conquista | Recompensa proposta |
|---|---|
| Primeira prova concluída | Primeiro acessório |
| 10 provas concluídas | Mochila |
| 100 questões respondidas | Livro especial |
| 7 dias de sequência | Item temático de sequência |
| Aprovação em simulado | Moldura especial |
Os itens não dão vantagens em provas. Além dos marcos gerais, fica uma
**conquista temática opcional**: concluir 50 provas militares para desbloquear
um chapéu militar. Ela não deve ser requisito nem ocupar o lugar de uma
conquista geral. Os critérios e a arte ainda podem ser refinados. Cada conquista
deve refletir atividade real verificável, sem inventar progresso. O item de
sequência é cosmético: não deve remover recompensas nem punir alguém por
interromper o ritmo, evitando pressão de uso diário ou gamificação infantil.
Ilustrações e modelos visuais enviados como referência não são assets aprovados;
usar arte original ou materiais com licença compatível.

Para a sequência, **atividade** inclui navegar e explorar o app, além de
resolver/revisar questões; não precisa concluir uma prova. Um dia sem atividade
interrompe a sequência, mas nunca remove itens cosméticos já conquistados.
**Decisão confirmada:** usar o fuso horário local do dispositivo e considerar
24 horas completas desde a última atividade; não basta a virada da data. O
horário e a data exibidos seguem o fuso local do dispositivo. **A conquista de
sete dias** exige atividade ao longo de sete períodos consecutivos de 24 horas;
completar 24 horas sem atividade reinicia a sequência, sem remover itens já
conquistados.

**Decisão confirmada sobre início:** a pessoa escolhe um conjunto inicial de
avatar; escolhe entre personagens prontos e depois ajusta as peças iniciais
disponíveis. Os demais itens ficam para desbloquear com conquistas.
**Decisão confirmada sobre edição:** pode alterar o avatar quando quiser, sem
custo, usando as peças iniciais e todos os itens já desbloqueados.
**Decisão confirmada sobre a coleção:** os itens bloqueados ficam visíveis no
catálogo desde o início, com o requisito de desbloqueio e o progresso atual.
**Decisão confirmada sobre desbloqueio:** ao cumprir uma conquista, o item é
liberado automaticamente e a pessoa recebe uma notificação, usando os canais
de notificação que tiver habilitados. A categoria de itens de avatar
desbloqueados começa ligada, mas pode ser desligada.

Como incentivo de retorno, a pessoa recebe um lembrete transparente após 24
horas completas sem atividade, ligado por padrão mas fácil de desligar.
**Decisão confirmada:** ele é enviado uma única vez por período de inatividade
e só volta a ser elegível quando a pessoa retoma a atividade e fica inativa
novamente. O horário/data seguem o fuso local do dispositivo. O lembrete não
pode fingir que existe prova nova. Só mencionar prova nova quando houver uma
novidade real; caso contrário, usar um convite honesto para voltar/explorar.

O avatar apareceria no perfil, publicações, comentários, rankings, lista de
amigos e salas de estudo, caso esses espaços façam parte do produto.

**Decisões confirmadas sobre interação:** seguir pode ser desfeito pelo mesmo
controle no perfil. Perfis começam públicos; em perfil público, seguir é
imediato. A pessoa pode ativar perfil privado, caso em que novos seguidores
precisam de aprovação. Esses pedidos ficam numa fila/lista no perfil para o
dono aceitar ou recusar; quem pediu vê **“Solicitação pendente”** até a decisão.
Se aceitar, o vínculo de seguimento é ativado e quem pediu recebe uma
notificação. Se recusar, o solicitante vê **“Solicitação recusada”** e espera
uma semana antes de pedir novamente para o mesmo perfil.
Visitantes de perfis privados veem apenas nome, `@`, avatar e bio; métricas e
restante do conteúdo ficam ocultos até aprovação.

A mensagem direta inicia uma solicitação de conversa; a pessoa destinatária
decide **Aceitar conversa** ou negar. Se negar, quem enviou recebe a mensagem
de estado **“Mensagem negada”**. Detalhes de limite e envio de novas
solicitações:

- após a primeira negativa, esperar uma semana antes de solicitar novamente à
  mesma pessoa;
- após a segunda negativa, esperar duas semanas;
- após uma terceira negativa, bloquear permanentemente novos pedidos de
  mensagem desse remetente para esse destinatário, salvo se essa pessoa
  iniciar/aceitar a conversa;
- essa limitação é somente entre aquelas duas contas.

Se uma pessoa receber recusas de três contas diferentes, abre-se uma
investigação separada: as mensagens são analisadas e a moderação avalia se
deve suspender temporariamente o envio de mensagens pela conta. A punição
global não é automática; depende da análise. **Decisão confirmada:** a duração
é definida caso a caso pela moderação; a pessoa recebe o motivo e pode
contestar.

Depois de aceita, a mensagem direta passa a ser um chat privado comum.
**Compartilhar uma prova** pode abrir a folha de compartilhamento do aparelho
(com opções como WhatsApp e **Prova Social**). Ao escolher Prova Social, a
pessoa seleciona um amigo da lista. **Decisão confirmada:** amigo é quem segue
a pessoa e é seguido por ela (seguimento mútuo), ou quem já tem uma conversa
direta aceita com ela. O destinatário recebe o link, abre a prova se tiver
acesso e pode respondê-la em particular pelo chat.

**Decisão confirmada:** o link não concede acesso automaticamente. Se a prova
for privada ou estiver só no aparelho do remetente e o destinatário não tiver
permissão, mostrar que está indisponível e orientar o dono a compartilhá-la/
publicá-la de forma autorizada. Enviar o link não altera a privacidade da prova;
também é preciso respeitar os direitos de redistribuição.

Métricas reais podem ser exibidas para outras pessoas, exceto as que a pessoa
escolher deixar privadas. **Decisão confirmada:** cada métrica tem seu próprio
controle público/privado. Toda estatística precisa derivar de atividade real;
não inventar dados para visitantes ou perfis sem histórico.

## Validações técnicas pendentes

- Validar com ground truth autorizado os critérios estruturais de questão não
  fazível e os resultados do scanner; não substituir essa medição por um corte
  no score heurístico atual.
- Confirmar modelo/configuração exatos do Inspirion 15 e do C85 antes do
  benchmark de explicações locais; o roteiro de medição está em
  [[Importação e OCR]].
- Implementar coleta de resultados humanos de moderação para medir falsos
  bloqueios e violações confirmadas. Curtidas e **“Isso me ajudou”** medem
  utilidade, não são rótulos automáticos de segurança.
- A estrutura v1 do JSON de feedback está escolhida e documentada em
  [[Importação e OCR]]. Antes de transmitir ou persistir anexos, auditar schema,
  Storage e controle de acesso existentes.

## Decisões já fechadas

- Não exibir confiança numérica para questão ou explicação na primeira versão;
  scores atuais não são probabilidades calibradas.
- Cada tentativa de prova de revisão guarda um snapshot de questões. Acertos
  saem dos erros pendentes e ficam no histórico; a pessoa pode pedi-los em uma
  fila separada de **Revisar de novo**.
- Explicações identificam claramente se são oficiais (com fonte), escritas por
  pessoa ou geradas por IA. Conteúdo misto é separado por trecho e rotulado.
## Estado da implementação

Este arquivo registra intenção discutida. Nenhum código foi alterado para
implementar estas ideias nesta rodada. O scanner tem uma parte funcional
(PDF/JSON/manual, parser, gabarito, quality gate e revisão) e lacunas explícitas
(câmera, feedback, discursivas na publicação, validação em aparelho). O estado
verificado está em
[[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Auditoria da área 9]]
e a especificação fechada, em [[Importação e OCR]]. O estado geral do produto
está em [[../00 - Central/Estado Atual|Estado Atual]]; o plano geral, em
[[../00 - Central/Plano Mestre|Plano Mestre]].
