---
tipo: area
area: comunidades
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: []
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: baixa
atualizado: 2026-11-04
---

# Comunidades

## Intenção

Comunidades devem surgir em torno de provas, questões, bancas, disciplinas ou
tópicos com intenção real e repetida, não de coincidência literal. Ciclo
pretendido: sugerida, ativa, dormente, arquivada ou reaberta. Precisa de
moderação, denúncia, antispam, deduplicação e privacidade.

## Perguntas ligadas a questões e descoberta social

- **Perfil social:** cada perfil tem URL própria e mostra nome, `@usuário`,
  bio curta opcional e avatar. A pessoa pode criar um personagem/avatar com
  várias opções de aparência, sem precisar usar uma foto real.
- A proposta discutida é que o avatar seja uma coleção cosmética que represente
  a trajetória acadêmica, com itens liberados por conquistas reais. Uma primeira
  lista de marcos foi aprovada para refinamento; detalhes estão no
  [[Fluxo de Entrada e Criação#Perfil|fluxo do perfil]]. Isso não deve dar
  vantagem em provas nem virar gamificação infantil.
- **Visibilidade:** perfis começam públicos. Quando a pessoa ativa o modo
  privado, visitantes veem apenas nome, `@usuário`, avatar e bio; métricas e
  restante do conteúdo ficam ocultos para quem não foi aprovado.
- **Seguir:** em perfis públicos, seguir é imediato e pode ser desfeito por
  **Deixar de seguir**. Em perfil privado, novos seguidores precisam ser
  aprovados pela pessoa. O pedido aparece numa lista/fila do perfil para o dono
  aceitar ou recusar; quem pediu vê **“Solicitação pendente”** até a decisão.
  O dono recebe uma notificação do novo pedido. Se aceitar, o vínculo de
  seguimento é ativado e quem pediu recebe uma notificação. Se recusar, quem
  pediu vê **“Solicitação recusada”** e espera uma semana antes de pedir
  novamente para o mesmo perfil.
- No perfil, também é possível iniciar uma mensagem direta. A solicitação de
  conversa só prossegue se a pessoa destinatária aceitar; se negar, quem enviou
  recebe **“Mensagem negada”**.
- Após a solicitação ser aceita, abre-se uma conversa privada de mensagens,
  como em um app de chat comum.
- **Regra proposta para pedidos negados:** após a primeira negativa, esperar
  uma semana antes de solicitar novamente à mesma pessoa; após a segunda,
  esperar duas semanas; após a terceira negativa, bloquear permanentemente
  novos pedidos de mensagem desse remetente para esse destinatário. A pessoa
  destinatária ainda pode iniciar/aceitar uma conversa. **Decisão confirmada:**
  essa limitação é somente entre o remetente e aquele destinatário.
- Se o remetente receber recusas de três contas diferentes, abrir uma
  investigação separada: revisar as mensagens e avaliar se deve haver uma
  suspensão temporária global do envio de mensagens. Isso não aplica punição
  global automaticamente; a decisão vem após a análise. **Decisão confirmada:**
  a duração é definida caso a caso pela moderação, que informa o motivo e
  permite contestação.
- Métricas iniciais do perfil: provas concluídas, provas publicadas, questões
  respondidas e pessoas ajudadas. Todas devem refletir atividade real.
  **Decisão confirmada:** cada métrica tem seu próprio controle
  público/privado, e todas começam públicas; a pessoa pode tornar cada uma
  privada individualmente. “Pessoas ajudadas” conta pessoas únicas que tocam
  **“Isso me ajudou”** em uma resposta da pessoa; visualizações e respostas
  enviadas não bastam.
- Uma dúvida publicada a partir da revisão permanece ligada à questão e pode
  receber respostas que ajudem também outras pessoas com a mesma dúvida.
- Cada questão pode ter uma URL canônica própria e compartilhável; provas e
  perfis também terão URLs próprias. Um link de resposta deve levar à questão
  e à resposta correspondente. Compartilhar uma questão não equivale a publicar
  a prova inteira.
- **Compartilhar prova com alguém:** a ação de compartilhar pode abrir a folha
  de compartilhamento do aparelho, com opções externas (como WhatsApp) e
  **Prova Social**. Ao escolher Prova Social, mostrar uma lista de amigos para
  escolher destinatários. O amigo recebe o link da prova, abre o conteúdo se
  tiver acesso e pode responder em particular pelo chat.
- **Definição confirmada de amigo:** entra na lista quem segue o remetente e é
  seguido por ele (seguimento mútuo), ou quem já tem uma conversa direta aceita
  com o remetente.
- **Decisão confirmada sobre acesso:** compartilhar o link não concede acesso
  automaticamente. Se a prova estiver privada ou só no aparelho do remetente e
  o destinatário não tiver permissão, mostrar que está indisponível e orientar
  o dono a compartilhá-la/publicá-la de forma autorizada.
- **Decisão confirmada sobre URL da questão:** a questão herda a privacidade e
  as permissões da prova de origem. Não pode ser publicada separadamente para
  contornar a privacidade da prova.
- Esse envio não muda por si só o estado privado/público da prova; direitos de
  redistribuição e elegibilidade de links públicos ainda precisam ser
  respeitados.
- Um link pode abrir a questão em uma página web pública ou direcionar para a
  mesma tela no aplicativo instalado. Para visitante, exibir somente conteúdo
  público e autorizado. A intenção descrita é poder abrir o link e ler a questão
  antes de autenticar; login é necessário para responder, perguntar, seguir e
  demais ações sociais. Isso refina a intenção anterior de exigir login para
  “usar” perguntas.
- **Identidade na pergunta:** ao perguntar, a pessoa escolhe exibir sua conta
  ou aparecer como anônima. A conta continua autenticada para publicar; a
  opção anônima oculta a identidade das outras pessoas sem eliminar o vínculo
  interno necessário a controles de abuso. **Decisão confirmada:** somente a
  própria pessoa e moderadores autorizados podem consultar a identidade real.
- Para respostas que não possam ser enviadas, a experiência desejada é mostrar
  **“Resposta não autorizada”** com os motivos (por exemplo, **conduta não
  apropriada** ou **palavra não apropriada**) e permitir editar e tentar
  novamente sem limite. A resposta só deve ser publicada quando passar na
  verificação apropriada.
- **Decisão confirmada:** casos de conteúdo incerto são encaminhados à revisão
  humana e não publicados antes da aprovação. Se o serviço estiver
  tecnicamente indisponível, manter o texto como rascunho não publicado e
  informar **“Não foi possível verificar; tente novamente”**; não tratar a
  falha técnica como violação.
- **Decisão confirmada:** se uma resposta for rejeitada e a pessoa discordar,
  ela pode solicitar revisão humana. O conteúdo continua não publicado até
  aprovação; também é possível editar e reenviar.
- **Decisão confirmada sobre retenção:** o texto fica acessível à equipe apenas
  enquanto a revisão está pendente. Após a decisão, apagar o texto rejeitado e
  manter somente o resultado e o motivo.
- **Decisão confirmada sobre acesso:** o dono do app e moderadores designados
  podem acessar a fila de revisão. A identidade do autor fica oculta por padrão
  e só pode ser revelada quando necessária e por pessoa autorizada.
- **Decisão confirmada sobre o resultado da revisão:** se a resposta for
  aprovada por uma pessoa moderadora, devolvê-la ao autor para confirmação
  explícita antes da publicação. Se for rejeitada, informar o motivo e permitir
  correção e reenvio sem publicá-la.
- Se aprovada, mas não confirmada pelo autor em até 7 dias, expirar e apagar o
  texto sem publicá-lo.
- **Decisão confirmada sobre denúncias:** respostas publicadas denunciadas ficam
  temporariamente ocultas quando três pessoas diferentes as denunciarem; a
  denúncia não determina, por si só, o resultado final. Antes de atingir três,
  mostrar junto à resposta **“1 de 3”** ou **“2 de 3”**. Repetir a denúncia com
  a mesma conta não aumenta a contagem.
- Sem violação confirmada, restaurar a resposta. Se a revisão confirmar
  violação, removê-la da visualização pública, informar o motivo ao autor e
  permitir correção e reenvio pela verificação normal.
- Quem denunciou recebe aviso quando a revisão terminar, com o desfecho sem
  exposição de dados privados do autor.
- Se a equipe concluir que não houve violação, além de restaurar a resposta,
  avisar as pessoas que fizeram uma pergunta sobre aquela questão de que a
  resposta voltou a ficar visível.
- Curtidas e avaliações **“Isso me ajudou”** contam como sinais positivos para
  avaliar a utilidade das respostas. Não são rótulos automáticos de segurança
  nem substituem decisão humana. O desempenho do classificador será medido pelas
  decisões de revisão: rejeições revertidas pelo moderador são falsos bloqueios;
  violações confirmadas após publicação são casos que passaram pelo classificador.
  Medir cada grupo sobre os respectivos casos revisados, guardando a versão do
  classificador e os totais/denominadores. Denúncias são sinal de revisão, com
  ocultação ao atingir três pessoas distintas. Curtidas e denúncias não alteram
  automaticamente a regra nem servem sozinhas para treinar o classificador.
- Motivos disponíveis para denúncia: ofensa/assédio/discriminação; palavrão ou
  linguagem inadequada; spam/propaganda; conteúdo que não responde à pergunta
  ou não faz sentido; exposição de dados pessoais.
- Denúncia não confirmada não gera punição por si só; pode ter sido feita de
  boa-fé. Medidas contra quem denuncia se limitam a abuso deliberado e repetido.
- Abuso deliberado e repetido confirmado por revisão humana gera restrição
  temporária da função de denúncia; a restrição permanece até revisão humana
  removê-la, e uma nova ocorrência pode escalar a medida.
- **Correção de nomenclatura/escopo:** o responsável chama de **PARSER** o
  scanner que digitaliza provas, valida questões e normaliza os formatos em
  uma estrutura comum. O PARSER pertence à ingestão de provas e questões; não
  é, por essa definição, um moderador de texto social nem um classificador de
  palavrões, conduta ou qualidade de respostas.
- Portanto, não atribuir ao PARSER a autorização ou o bloqueio de respostas
  sociais. **Decisão confirmada:** usar um classificador dedicado no servidor,
  separado do PARSER; resultados incertos vão para revisão humana. A capacidade
  técnica e a política de falsos bloqueios precisam ser avaliadas antes de
  implementar.
- **Perguntas a responder** é uma aba permanente da comunidade, disponível
  independentemente do histórico de uso, para descobrir perguntas abertas e
  contribuir respondendo.
- **Para você** é um feed contínuo de recomendações, principalmente de provas
  que a pessoa pode querer fazer. Deve usar sinais reais de interesse: por
  exemplo, após resolver uma prova de Barro Branco, pode recomendar uma nova
  edição daquela prova. Perguntas ligadas a provas/assuntos que a pessoa
  conhece podem aparecer ocasionalmente entre as recomendações, para que ela
  possa ajudar.
- O feed personalizado pode considerar provas e assuntos pesquisados ou feitos.
  Seguir alguém prioriza reciprocamente as perguntas dessa pessoa no feed dela
  e vice-versa; as recomendações continuam relevantes e não devem ser só uma
  lista de posts de seguidos.
- **Conversa da questão:** a pergunta e as contribuições aparecem como uma
  sessão de comentários/mensagens ligada à questão. Uma resposta aparece como
  mensagem no fio e outras pessoas podem continuar ajudando.
- Ao tocar e segurar uma pergunta ou mensagem, oferecer ações como **Responder**
  e **Referenciar**. Responder inicia uma resposta direcionada à mensagem
  escolhida. Referenciar permite localizar/inserir uma referência a uma
  mensagem na composição, semelhante a um link de citação em mensageiros; tocar
  na referência leva diretamente à mensagem referenciada.
- **Decisão confirmada:** respostas aparecem aninhadas sob a pergunta ou
  mensagem à qual respondem, preservando o contexto da conversa.
- A pessoa que publica a pergunta recebe notificações quando ela é respondida.
  Pode escolher **Silenciar/Sair da questão** para parar de receber avisos
  daquela conversa; isso só interrompe o acompanhamento, não apaga a pergunta nem
  remove a pessoa da conversa.
- Mesmo com a conversa silenciada, uma menção direta à pessoa (`@nome`) gera
  uma notificação de que ela foi mencionada.
- **Decisão confirmada:** avisos aparecem tanto na central dentro do app quanto
  como push do aparelho. Tocar no ícone de perfil/conta no canto superior
  direito abre um modal com uma seção **Notificações** e outra de
  **Configurações**. Uma notificação recente também pode surgir como aviso
  breve/pop-up.
- A seção de notificações mostra um contador quando há novidades e uma lista
  das recebidas, incluindo provas novas, atividade de pessoas seguidas,
  pedidos de seguidores e decisões dos pedidos enviados, itens de avatar
  desbloqueados, respostas, menções e lembrete de retorno após inatividade
  (uma vez por período de inatividade).
  Se houver mais de três, a lista fica
  recolhida e oferece
  **Ver todas as notificações**.
- **Decisão confirmada:** tocar em uma notificação marca-a como lida e abre o
  conteúdo relacionado (por exemplo, questão, resposta ou prova). O contador
  representa itens não lidos. Itens não lidos ficam destacados, com borda
  luminosa e uma pulsação sutil; itens lidos perdem cor e ficam acinzentados.
  Qualquer movimento deve respeitar a preferência de redução de movimento e o
  estado também precisa ser distinguível sem depender só de cor/animação.
- **Decisão confirmada:** a pessoa pode escolher a ordem das seções
  **Notificações** e **Configurações** no modal.
- **Configurações iniciais aprovadas:** canais separados para push e para avisos
  na central; controles por categoria para respostas às minhas perguntas,
  respostas às minhas mensagens, menções, atividade de pessoas seguidas, provas
  novas/atualizadas relevantes, perguntas recomendadas para responder e pedidos
  para seguir meu perfil privado/decisões dos meus pedidos e itens de avatar
  desbloqueados. Incluir lembrete transparente de retorno após 24 horas
  completas sem atividade, enviado uma única vez até a pessoa voltar a ter
  atividade e ficar inativa novamente. Exibir horário/data no fuso local do
  dispositivo. Também permitir desligá-lo, configurar período silencioso e
  silenciar uma conversa específica.
  Desligar push não apaga o histórico da central; menções continuam destacadas
  e não são suprimidas pelo silêncio de uma conversa.
- **Padrões confirmados:** deixar inicialmente ligadas todas as categorias
  listadas, incluindo respostas às minhas perguntas e mensagens, menções,
  atividade de pessoas seguidas, provas relacionadas e perguntas recomendadas.
  Também começam ligadas as notificações de pedidos para seguir perfil privado
  e decisões dos pedidos enviados, além de novos itens de avatar desbloqueados.
  O lembrete transparente de retorno após inatividade também começa ligado e
  pode ser desligado; é enviado uma vez por período de inatividade. Categorias
  futuras não listadas começam desligadas até a pessoa ativá-las.
- A conversa é coletiva e reutilizável: quem abrir a questão pode acompanhar o
  contexto e as respostas anteriores. O formato visual exato, a organização de
  edição/remoção e detalhes dos controles de notificação ainda não foram
  definidos.
- Visibilidade detalhada, denúncia, moderação, antispam e controles sobre
  respostas e publicações ainda precisam ser definidos. Também é preciso
  proteger conteúdo de provas privadas/rascunhos e verificar a legitimidade de
  compartilhar cada questão. Não assumir que esse sistema já existe no código.

## Estado do código

Não houve nesta fase uma auditoria profunda para comprovar sistema dinâmico de
comunidades, lifecycle, RLS, URLs canônicas, feed personalizado, perguntas
ligadas a questões, identidade anônima, perfis/avatares, seguimento, mensagens
diretas ou moderação. Não assumir que existe pela intenção registrada.

## Fonte

[AGENTS.md — comunidades dinâmicas](../../AGENTS.md).
