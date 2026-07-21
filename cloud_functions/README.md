# mtengatenga-ai-proxy

This folder contains the Google Cloud Functions proxy used by the Flutter app for:

- `/ai-chat` and `/ai-chat-stream` via Vertex AI
- `/tts` via Cloud Text-to-Speech
- `/translate` via Cloud Translation
- `/embed-query` and `/embed-artifacts` via Vertex AI embeddings

## Important: you may not need to run this locally

If `mtengatenga_ar/.env` already points `CLOUD_FUNCTION_URL` to a deployed Cloud Function, the app can use that directly. In that setup, the Flutter app can start without a local proxy process.

Run this locally only when you want to develop or debug the proxy itself.

## Local setup

1. Install dependencies in this folder:

```powershell
npm install
```

2. Sign in to Google Cloud and pick the project:

```powershell
gcloud.cmd auth login
gcloud.cmd config set project YOUR_PROJECT_ID
```

3. Create Application Default Credentials for the Node client libraries:

```powershell
gcloud.cmd auth application-default login
```

4. Export the project id into the current shell:

```powershell
$env:GOOGLE_CLOUD_PROJECT = (gcloud.cmd config get-value project)
```

5. Run the preflight check:

```powershell
npm run check:local
```

6. Start the proxy:

```powershell
npm run dev:checked
```

The local health check will be available at:

```text
http://127.0.0.1:8080/
```

## Point the Flutter app at the local proxy

Set `CLOUD_FUNCTION_URL` in `mtengatenga_ar/.env` based on where the app is running:

- Windows desktop / web / iOS simulator: `http://127.0.0.1:8080`
- Android emulator: `http://10.0.2.2:8080`
- Physical phone on the same Wi-Fi: `http://YOUR_COMPUTER_LAN_IP:8080`

If you keep `CLOUD_FUNCTION_URL` pointed at a deployed Cloud Function, you do not need any local proxy startup step for normal app launches.

## Safer Gen 2 deploy

If you deploy with `gcloud functions deploy`, avoid packing multiple variables into one `--set-env-vars` value. For multiple variables, prefer an env file:

```powershell
gcloud.cmd functions deploy aiProxy `
  --gen2 `
  --runtime=nodejs20 `
  --region=us-central1 `
  --trigger-http `
  --allow-unauthenticated `
  --entry-point=aiProxy `
  --memory=512MB `
  --timeout=120s `
  --min-instances=1 `
  --source=. `
  --env-vars-file=env.yaml
```

Use [env.yaml.example](/C:/Museum%20App%20UI/cloud_functions/env.yaml.example) as a template, copy it to `env.yaml`, and keep the real file out of git.

If you use `--set-env-vars` directly, the values must be comma-separated, for example:

```powershell
--set-env-vars "GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID,SUPABASE_URL=https://your-project.supabase.co,SUPABASE_SERVICE_KEY=YOUR_SERVICE_ROLE_KEY"
```

## Common failure

If the proxy starts but requests return an error like `Could not load the default credentials`, it means ADC is missing for local development. Run:

```powershell
gcloud.cmd auth application-default login
```

Then export the project id again and restart the proxy.
