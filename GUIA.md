# Ganhos do Mês: colocando o site no ar

O site é o mesmo hub, com três diferenças:

- Cada pessoa entra com a própria conta Google.
- Cada pessoa só vê os próprios dados.
- Cada pessoa liga o próprio Google Agenda.

Tudo roda em três serviços gratuitos pra começar:

- **Supabase**: login e banco de dados.
- **Google Cloud**: permissão de login e acesso ao Google Agenda.
- **Vercel**: hospedagem do site.

Reserve uns 40 minutos. Os nomes dos menus podem mudar um pouco com o tempo; se algo não bater, me manda um print.

## Arquivos da pasta

| Arquivo | O que é |
|---|---|
| `index.html` | O site inteiro |
| `config.js` | Onde você cola as 3 chaves (passo 5) |
| `privacidade.html` | Política de privacidade (o Google exige) |
| `schema.sql` | Cria o banco com a regra "cada um só lê o seu" e a aprovação de usuários |
| `admin.html` | Sua página pra aprovar, bloquear e definir plano de cada usuário |
| `vercel.json` | Configuração da hospedagem |
| `backup-wender-2026-10-12.json` | Seus dados atuais, pra restaurar no site |

---

## 1. Subir os arquivos (GitHub + Vercel)

1. Crie uma conta em **github.com**.
2. Clique em **New repository**, dê o nome `ganhos-do-mes` e escolha **Private**.
3. Clique em **uploading an existing file** e arraste todos os arquivos da pasta, **menos o backup** (o backup é só seu e não deve ir pro site). Depois clique em **Commit changes**.
4. Entre em **vercel.com** com a conta do GitHub.
5. Clique em **Add New → Project**, importe o `ganhos-do-mes` e clique em **Deploy**. Em *Framework*, deixe **Other**.
6. Anote o endereço que aparecer, algo como `https://ganhos-do-mes-xxxx.vercel.app`. Nos próximos passos ele é chamado de **SEU-SITE**.

## 2. Banco de dados (Supabase)

1. Entre em **supabase.com** e clique em **New project**.
2. Em *Region*, escolha **South America (São Paulo)**. Crie uma senha forte e guarde.
3. Abra o `schema.sql` num editor de texto e confira o e-mail do administrador (linha do `insert into public.admins`). É ele que vira o administrador.
4. No Supabase, abra o menu **SQL Editor**, cole todo o conteúdo do `schema.sql` e clique em **Run**. Deve aparecer *Success*.
5. Abra **Project Settings → API** (ou **Data API**) e anote:
   - **Project URL** (ex.: `https://abcd.supabase.co`), que é o **SEU-SUPABASE**;
   - a chave **anon public**.

## 3. Google Cloud (login + Agenda)

1. Entre em **console.cloud.google.com** e crie um projeto novo chamado "Ganhos do Mês".
2. Abra **APIs e serviços → Biblioteca**, procure **Google Calendar API** e clique em **Ativar**.
3. Abra **Google Auth Platform** (ou "Tela de consentimento OAuth") e configure:
   - Tipo de usuário: **Externo**.
   - Nome do app, e-mail de suporte e e-mail de contato.
   - Página inicial: SEU-SITE. Política de privacidade: `SEU-SITE/privacidade`.
   - Domínios autorizados: o domínio do SEU-SITE (ex.: `ganhos-do-mes-xxxx.vercel.app`) e `supabase.co`.
   - Em **Acesso a dados / Escopos**, adicione `.../auth/calendar.events`.
   - Em **Público / Usuários de teste**, adicione o seu e-mail e o de quem for testar.
4. Abra **Clientes** (ou **Credenciais → Criar credenciais → ID do cliente OAuth**) e configure:
   - Tipo: **Aplicativo da Web**.
   - **Origens JavaScript autorizadas**: SEU-SITE.
   - **URIs de redirecionamento autorizados**: `SEU-SUPABASE/auth/v1/callback`.
   - Crie e anote o **ID do cliente** e a **Chave secreta do cliente**.

## 4. Ligar o Google ao Supabase

1. No Supabase, abra **Authentication → Sign In / Providers → Google** e ative.
2. Cole o **ID do cliente** e a **Chave secreta** do passo 3 e salve.
3. Abra **Authentication → URL Configuration** e configure:
   - **Site URL**: SEU-SITE.
   - **Redirect URLs**: adicione SEU-SITE.

## 5. Preencher o `config.js`

No GitHub, abra o `config.js`, clique no lápis (editar), troque os três valores e clique em **Commit**:

```js
SUPABASE_URL: "SEU-SUPABASE",
SUPABASE_ANON_KEY: "a chave anon public",
GOOGLE_CLIENT_ID: "o ID do cliente do Google"
```

A Vercel publica de novo sozinha em cerca de 1 minuto.

Essas chaves podem ficar no site, porque são públicas por natureza. A chave secreta do Google **não** vai aqui: ela fica só no Supabase.

## 6. Testar

1. Abra SEU-SITE, clique em **Entrar com Google** e entre com o e-mail que você colocou como usuário de teste.
2. Clique em **Conectar agenda** no topo e autorize.
3. Abra o menu **Conta → Restaurar dados** e escolha o `backup-wender-2026-10-12.json`. Seus 25 lançamentos aparecem, com os nomes "Meus" e "Cut" que você usa.
4. Pra testar a agenda, lance um trabalho com data e confira se ele apareceu no Google Agenda.

---

## Como funciona pra outras pessoas

- **Aprovação**: quem entra pela primeira vez fica como **pendente** e vê "Recebemos seu pedido de acesso". Você abre **Conta → Usuários do site**, aprova ou bloqueia. Quando você aprova, a tela da pessoa libera sozinha em até 20 segundos.
- **Plano e validade**: na mesma página você marca o plano (Grátis, Pago, Cortesia) e uma data de validade. Quando a data passa, a pessoa perde o acesso até você renovar. Isso já deixa o caminho pronto pra assinatura.

- **Primeiro acesso**: a pessoa entra com o Google e o hub começa vazio. Os tipos iniciais são **Freela**, **Projetos** e **Empresa** (pra salário ou cliente fixo), e todos podem ser renomeados e recoloridos em *Editar*.
- **Agenda**: depois de aprovada, a pessoa vê um aviso pedindo pra conectar o Google Agenda. Com ela conectada, todo trabalho lançado, editado ou apagado vai direto pra agenda. Se lançar algo com a agenda desconectada, o trabalho fica marcado e é enviado sozinho assim que ela conectar de novo.
- **Duração do acesso à agenda**: a pessoa clica em **Conectar agenda**. O acesso dura cerca de 1 hora. Quando vence, o hub tenta renovar no próximo clique; se não conseguir, o botão vira **Reconectar agenda**.
- **Importar da agenda**: fica no menu Conta e é manual. Puxa os eventos do mês atual e dos 3 próximos que estão com a cor de algum tipo (o tipo "Empresa" fica de fora).
- **Backup**: no menu Conta, a pessoa pode baixar os próprios dados quando quiser.

## Antes de abrir pra todo mundo

1. **Modo de teste do Google**: enquanto o app estiver em *Teste*, só entram os e-mails cadastrados como usuários de teste no Google Cloud, até 100. Ou seja, nessa fase cada pessoa precisa ser liberada em dois lugares: no Google Cloud e na sua página de usuários. Pra abrir pra qualquer pessoa, você clica em **Publicar app**, e aí só a sua aprovação no site vale.
2. **Verificação do Google**: como o site mexe na agenda das pessoas, o Google pede uma **verificação** do app (pode levar de dias a semanas). Ela pede:
   - política de privacidade;
   - um vídeo curto mostrando o uso da agenda;
   - de preferência, um **domínio próprio** (ex.: `ganhosdomes.com.br`).

   Até a verificação sair, as pessoas veem um aviso "o Google não verificou este app" e o limite é de 100 usuários.
3. **Contato na política**: troque `SEU-EMAIL-DE-CONTATO` no `privacidade.html` por um e-mail de contato.
4. **Planos gratuitos**:
   - O Supabase pausa o projeto depois de 1 semana sem nenhum acesso (é só reativar no painel).
   - O plano gratuito da Vercel é pra uso não comercial. Se um dia você cobrar pelo site, vai precisar do plano pago.

## O que continua no Claude

O painel do Claude e as tarefas automáticas (importação diária, gravações da Cut, Nota da Cut) continuam funcionando como hoje. O site é separado: o que você lançar num não aparece no outro.

Quando quiser passar a usar só o site, me avisa que eu ajusto as tarefas.
