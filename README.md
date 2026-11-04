# Prova Social

Encontre ou importe uma prova, resolva no seu ritmo e descubra exatamente o que precisa estudar.

## 🎯 Nossa Proposta

Transforme provas em aprendizado real. Não é apenas outro app de estudos — é uma plataforma completa para descobrir, importar, resolver, revisar e discutir provas e questões.

## 🚀 Fluxo Principal

**Descobrir → Salvar → Fazer → Errar → Entender → Discutir → Melhorar → Refazer**

## 📱 Para Quem é?

- Estudantes que querem provas reais de concurso e faculdade
- Professores que desejam compartilhar material didático
- Qualquer pessoa que queira testar seus conhecimentos

## ✨ Funcionalidades Principais

### 🔍 Descoberta
- Busque por disciplina, banca, concurso ou ano
- Filtre por assuntos seguidos
- Veja provas recentes da comunidade

### 💾 Importação
- PDFs (com OCR local no Android)
- Imagens
- Criação manual de questões
- Dashboard de progresso da importação
- Questões completas podem ser resolvidas sem concluir toda a revisão; questões incompletas ficam de fora da tentativa após confirmação
- Revisão do gabarito continua obrigatória antes de publicar para a comunidade

### ⏱️ Modo Foco
- Cronômetro configurável: livre, tempo total da prova ou tempo por questão
- Contagem regressiva com aviso de tempo esgotado e cronômetro ocultável
- Interface limpa, sem distrações
- Navegação entre questões
- Marcar para revisão

### 📊 Resultado e Revisão
- Percentual sobre questões corrigíveis
- Contagem de acertos, erros e questões sem gabarito
- **Prova das erradas**: gere uma prova apenas com questões que errou
- Revisão questão a questão com gabarito (ainda sem explicação)

### 👤 Perfil e Sociais
- Perfil com conta, provas salvas e histórico de resultados
- Seguir assuntos
- Discussão por questão
- Provas publicadas pela comunidade, com origem visível

## 📱 Experiência Móvel

O aplicativo foi desenvolvido para celular primeiro:

- Interface rápida e responsiva
- Target de toque ~48×48 px
- Tema escuro em todo o app (a escolha de tema ainda não existe)
- Suporte à redução de movimento
- Loading que preserva o formato da página

## 📥 Como Começar

1. **Visitante**: Pode explorar e pesquisar sem conta
2. **Login**: Opcional para ações persistentes (salvar, publicar, sincronizar)
3. **Primeira prova**: Busque por um tema ou importe um PDF

## 📦 Tecnologias

| Área | Tecnologia |
|------|------------|
| Aplicativo | Flutter / Dart |
| Backend | Supabase |
| Autenticação | Supabase Auth |
| OCR | Google ML Kit / PaddleOCR |
| PDF | pdfrx |
| Web | Flutter Web |
| CI/CD | GitHub Actions |

## 📥 Instalação Rápida

```sh
# Como visitante (sem conta)
# - Acesse o site ou abra o Flutter Web
# - Busque por provas públicas
# - Teste o modo de demonstração

# Para desenvolvedores
git clone https://github.com/NAGCODE-Dev/Prova-Social.git
cd Prova-Social
flutter pub get

# Configurar Supabase (necessário para auth e sincronização)
cp .env.supabase.json.example .env.supabase.json
# Preencha com SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY

# Rodar no navegador
./tool/flutter_with_supabase.sh run -d chrome

# Build APK debug
./tool/flutter_with_supabase.sh build apk --debug
```

## 📱 Telas Principais

### Home
- Saudação discreta
- Busca em destaque
- Continuar de onde parou
- Recomendações reais

### Explorar
- Busca "O que você quer estudar?"
- Filtros por banca, concurso, disciplina
- Resultados em lista compacta

### Modo Foco
- Cronômetro configurável (livre, total da prova ou por questão)
- Questão atual e progresso
- Alternativas com resposta instantânea
- Marcar para revisão

### Resultado
- Percentual sobre questões corrigíveis
- Contagem: acertos, erros, em branco, sem gabarito
- **Prova das erradas**: gere nova prova com questões erradas
- Cada questão: sua resposta e o gabarito correto

### Importação
- Dashboard de progresso em etapas reais
- Detecta layout e ordem de leitura
- OCR apenas onde necessário
- Revisão manual antes de publicar

## 📱 HIG (Human Interface Guidelines) aplicadas

- **Toque imediato**: feedback em 80-140 ms
- **Sem indicação apenas por cor**: estados usam texto + ícone + borda
- **Targets de toque ~48×48 px**
- **Loading consciente**: skeleton que preserva formato da página
- **Modo Foco**: cronômetro isolado, não bloqueia ações
- **Redução de movimento**: respeita configuração do sistema
- **Uma ação principal por tela**: não sobrecarrega o usuário

## 🧭 O que ainda não existe

Listado para que a promessa do produto e o estado real do app não se confundam:

- **Explicação de questão**: `Question` não tem campo de explicação e a revisão mostra apenas o gabarito. Depende de conteúdo, não só de interface.
- **Seguir provas, bancas e concursos**: só `topic_follows` (assuntos) é usado pelo app. As tabelas `profile_follows`, `collections` e `collection_exams` existem apenas no desenho de backend (`supabase/prova_social_backend_v1.sql`), sem migração aplicada.
- **Comunidades**: não há entidade, tela ou consulta de comunidade.
- **Questões discursivas**: o modelo de questão aceita uma única alternativa correta.
- **Tema claro**: `AppTheme.light` existe, mas o app força `ThemeMode.dark` e o Modo Foco ainda usa cores escuras fixas. Uma tela de preferência é pré-requisito.

## 📦 Distribuição

- **Flutter Web**: `/app/` ou rota oficial
- **APK por arquitetura**: releases novas distribuem apenas os APKs menores (`arm64-v8a`, `armeabi-v7a` e `x86_64`); o atualizador escolhe o compatível com o aparelho. O APK universal continua como fallback para releases antigas.
- **Site**: `https://prova-social.pages.dev/`
- **Atualizações**: O app consulta releases do GitHub de forma resiliente

## 📜 Licença

Prova Social - Código aberto para fins educacionais.
Não publicar, fazer commit, criar tag, release ou push sem autorização explícita.

---

**Prova Social** — Encontre, importe, resolva e melhore seus conhecimentos.
