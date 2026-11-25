# Rodar e publicar o proxy

O proxy usa o Firebase do projeto `elo-squad-app` no plano gratuito (Spark):
Firestore, Authentication e Cloud Messaging. Ele pode rodar em dois lugares:

- **No PC**, para testar com o celular na mesma rede Wi-Fi.
- **No Render** (plano gratuito, sem cartão), para o grupo usar no dia a dia. As
  tarefas do ranking rodam no GitHub Actions.

## Credencial do Firebase (uma vez só)

O proxy escreve no Firestore e manda push com uma conta de serviço:

1. Firebase Console → ⚙️ **Configurações do projeto** → **Contas de serviço** →
   **Gerar nova chave privada**.
2. Salve o arquivo como `backend/firebase-sa.json` (ignorado pelo git) e
   acrescente ao `backend/.env`:

   ```
   FIREBASE_CREDENTIALS_FILE=firebase-sa.json
   ```

Essa chave dá acesso total ao projeto: nunca a versione nem a mande por chat.

## No PC (teste com o celular)

```powershell
cd backend
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Na primeira vez, o Windows pergunta sobre o firewall: permita em **redes
privadas**. Depois, com o celular no mesmo Wi-Fi e conectado por USB:

```powershell
ipconfig   # anote o "Endereço IPv4" do Wi-Fi, ex.: 192.168.0.10
cd app
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

## No Render (publicação)

1. Crie uma conta em https://render.com entrando com o GitHub.
2. **New → Blueprint**, escolha o repositório `elo-squad`. O Render lê o
   `render.yaml` e pede os valores que faltam:
   - `RIOT_API_KEY`: a chave da Riot.
   - `JOBS_SECRET`: um valor aleatório, por exemplo gerado com
     `python -c "import secrets; print(secrets.token_urlsafe(32))"`.
3. No serviço criado: **Environment → Secret Files → Add Secret File**, com o
   nome `firebase-sa.json` e o conteúdo do arquivo da conta de serviço.
4. Anote a URL do serviço (`https://elo-squad-proxy-xxxx.onrender.com`).

Cada push que muda `backend/` publica de novo sozinho.

**Chave diária da Riot:** enquanto for a dev key, troque `RIOT_API_KEY` em
**Environment** a cada dia em que forem usar o app. Salvar reinicia o serviço.

**Plano gratuito:** o serviço dorme após 15 min sem uso e leva uns 30–60 s
para acordar. O app o acorda ao abrir e espera até 60 s por resposta.

### Tarefas do ranking (GitHub Actions)

No GitHub, no repositório: **Settings → Secrets and variables → Actions**.

- Aba **Variables**: `PROXY_URL` = a URL do Render (sem `/` no fim).
- Aba **Secrets**: `JOBS_SECRET` = o mesmo valor do Render.

O workflow `.github/workflows/jobs.yml` atualiza o ranking a cada hora e fecha
a semana na segunda às 00:05 (Brasília). Para testar na hora: **Actions →
Tarefas do ranking → Run workflow**. O GitHub pode atrasar tarefas agendadas
em alguns minutos e as desliga após 60 dias sem commits no repositório.

### App apontando para o Render

```powershell
cd app
flutter run --dart-define=API_BASE_URL=https://elo-squad-proxy-xxxx.onrender.com
```

## Alternativa: Google Cloud Run

Exige o plano Blaze (com cartão). O `backend/Dockerfile` serve para os dois:
`gcloud run deploy elo-squad-proxy --source backend --region
southamerica-east1 --allow-unauthenticated --max-instances 1`, com os
segredos no Secret Manager e as tarefas no Cloud Scheduler.
