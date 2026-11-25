# Publicação do proxy (Google Cloud Run)

O proxy roda no Cloud Run, no mesmo projeto do Firebase (`elo-squad-app`), em
`southamerica-east1` (São Paulo, a mesma região do Firestore). Duas tarefas do
Cloud Scheduler atualizam o ranking.

## Uma vez só

1. **Firebase Console → Authentication → Sign-in method → Google → Ativar.**
   Depois, no PC, regere a configuração do app (o `google-services.json` passa
   a ter o client ID do login com Google):

   ```powershell
   cd app
   & "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat" configure --project=elo-squad-app --platforms=android --android-package-name=io.github.leddro.elo_squad --yes
   ```

2. **Plano Blaze** (Firebase Console → Upgrade). O Cloud Run e o Cloud
   Scheduler exigem faturamento ativo; o uso do app fica dentro da cota
   gratuita. Vale criar um alerta de orçamento (ex.: US$ 1) em Faturamento.

3. **Chave de produção da Riot.** A dev key expira em 24 h. Peça uma
   *Personal API Key* em https://developer.riotgames.com (não expira; uso
   pessoal e para amigos).

4. **Google Cloud CLI**: instale (https://cloud.google.com/sdk/docs/install) e:

   ```powershell
   gcloud auth login
   gcloud config set project elo-squad-app
   gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com cloudscheduler.googleapis.com
   ```

5. **Segredos** (Secret Manager; nunca em variável de ambiente comum):

   ```powershell
   "RGAPI-...sua-chave..." | gcloud secrets create riot-api-key --data-file=-
   python -c "import secrets; print(secrets.token_urlsafe(32))" | gcloud secrets create jobs-secret --data-file=-

   # A conta de serviço padrão do Cloud Run precisa ler os segredos:
   $SA = "$(gcloud projects describe elo-squad-app --format='value(projectNumber)')-compute@developer.gserviceaccount.com"
   gcloud projects add-iam-policy-binding elo-squad-app --member="serviceAccount:$SA" --role="roles/secretmanager.secretAccessor"
   ```

## Publicar (a cada versão nova do proxy)

```powershell
gcloud run deploy elo-squad-proxy `
  --source backend `
  --region southamerica-east1 `
  --allow-unauthenticated `
  --max-instances 1 `
  --set-secrets "RIOT_API_KEY=riot-api-key:latest,JOBS_SECRET=jobs-secret:latest"
```

- `--source`: o Cloud Build monta a imagem com o `backend/Dockerfile`.
- `--allow-unauthenticated`: a rota é pública, mas toda rota da Riot exige o
  token do Firebase, e as de tarefas exigem o `X-Jobs-Secret`.
- `--max-instances 1`: uma instância só mantém o cache em memória coerente e
  protege a cota da Riot.

O comando mostra a URL (`https://elo-squad-proxy-....run.app`).

## Tarefas agendadas (Cloud Scheduler)

```powershell
$URL = "https://elo-squad-proxy-....run.app"
$SECRET = gcloud secrets versions access latest --secret=jobs-secret

# Ranking da semana: a cada hora.
gcloud scheduler jobs create http refresh-rankings --location southamerica-east1 `
  --schedule "0 * * * *" --time-zone "America/Sao_Paulo" `
  --uri "$URL/jobs/refresh-rankings" --http-method POST --headers "X-Jobs-Secret=$SECRET"

# Fecha a semana: segunda-feira, 00:05.
gcloud scheduler jobs create http close-week --location southamerica-east1 `
  --schedule "5 0 * * 1" --time-zone "America/Sao_Paulo" `
  --uri "$URL/jobs/close-week" --http-method POST --headers "X-Jobs-Secret=$SECRET"
```

## App apontando para o proxy publicado

```powershell
cd app
flutter run --dart-define=API_BASE_URL=https://elo-squad-proxy-....run.app
```
