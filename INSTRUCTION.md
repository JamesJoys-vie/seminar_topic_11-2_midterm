# How to Configure and Run This Project by Yourself

This guide explains how to set up, test, run, and optionally expose the Student Management API from your own machine.

The project has three moving parts:

- Python runs the FastAPI application in `main.py`.
- Node.js installs local test tools, especially Newman.
- PowerShell scripts automate Build, Test, Deploy, Stop, and ngrok verification steps.

Run every command from the project root, the folder that contains `main.py`, `requirements.txt`, `package.json`, and `scripts/`.

## 1. Install Required Tools

Install these tools first:

- Python 3.13, or another compatible Python 3 version.
- Node.js and npm.
- PowerShell.
- ngrok, only if you want a public URL.

Check the tools:

```powershell
python --version
node --version
npm --version
$PSVersionTable.PSVersion
```

If one of those commands is missing, install that tool before continuing.

## 2. Install Project Dependencies

Install the Node.js dependencies:

```powershell
npm install
```

This creates `node_modules/` and installs Newman locally. You do not need a global Newman installation.

Build the Python environment:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

The build script:

1. Checks that Python and `requirements.txt` are available.
2. Creates or reuses `.venv/`.
3. Installs packages from `requirements.txt`.
4. Verifies that `main.py` can be imported.
5. Runs `pip check`.

When this passes, the project is configured for local use.

## 3. Run the API Locally

Start the API:

```powershell
npm run deploy:local
```

By default, the API runs at:

```text
http://127.0.0.1:8080
```

Open the API docs:

```text
http://127.0.0.1:8080/docs
```

Check the health endpoint:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/actuator/health
```

Expected result:

```text
status: UP
```

Stop the API when finished:

```powershell
npm run stop:local
```

## 4. Run on a Custom Port

Use a custom port if `8080` is busy or if ngrok is forwarding to a different port.

Deploy only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-local.ps1 -Port 8081
```

Full local CI/CD workflow:

```powershell
npm run cicd:local -- -Port 8081
```

The `--` after `npm run cicd:local` is important. It tells npm to pass the remaining arguments to the PowerShell script.

With port `8081`, use:

```text
http://127.0.0.1:8081
http://127.0.0.1:8081/docs
http://127.0.0.1:8081/actuator/health
```

## 5. Run the API Tests

Run the Newman API test suite:

```powershell
npm run test:api
```

The test script:

1. Runs the Build phase.
2. Installs npm dependencies unless skipped.
3. Converts the Postman YAML workspace into Newman JSON files.
4. Starts a temporary Uvicorn server.
5. Waits for `/actuator/health`.
6. Runs Newman.
7. Writes reports under `reports/newman/`.
8. Stops the temporary server.

Run tests on a custom port:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test.ps1 -Port 8081
```

## 6. Run the Full Local CI/CD Workflow

Run the whole workflow:

```powershell
npm run cicd:local
```

This runs:

1. Stop any existing local deployment.
2. Build the Python environment.
3. Test the API with Newman.
4. Deploy the API locally.
5. Verify the local health endpoint.
6. Write a summary to `.runtime/pipeline-summary.txt`.

If any phase fails, the pipeline stops immediately.

Run the full workflow on another port:

```powershell
npm run cicd:local -- -Port 8081
```

## 7. Expose the API with ngrok

The project can verify a public ngrok URL, but it does not start ngrok for you. Start ngrok in a separate terminal first.

For the default port:

```powershell
ngrok http http://127.0.0.1:8080
```

For port `8081`:

```powershell
ngrok http http://127.0.0.1:8081
```

Use `127.0.0.1` instead of `localhost` to avoid IPv4/IPv6 forwarding confusion on Windows.

ngrok will show a forwarding URL, for example:

```text
https://real-ngrok-url.ngrok-free.dev -> http://127.0.0.1:8081
```

Copy the real URL from your ngrok terminal. Do not use placeholder text such as `https://your-url.ngrok-free.dev`.

Then run the pipeline with the same port and the real ngrok URL:

```powershell
npm run cicd:local -- -Port 8081 -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"
```

The pipeline will check:

```text
https://real-ngrok-url.ngrok-free.dev/actuator/health
```

You can also store the public URL in the current PowerShell session:

```powershell
$env:NGROK_PUBLIC_URL = "https://real-ngrok-url.ngrok-free.dev"
npm run cicd:local -- -Port 8081
```

Verify only ngrok:

```powershell
npm run verify:ngrok -- -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"
```

## 8. API Login and Base URL

Default local base URL:

```text
http://127.0.0.1:8080
```

Demo credentials:

```text
Username: admin
Password: admin123
```

Public endpoint:

```text
GET /actuator/health
```

Login endpoint:

```text
POST /api/auth/login
```

Protected student endpoints require a bearer token from login.

## 9. Generated Files

These files are generated locally:

| Path | Purpose |
|---|---|
| `.venv/` | Python virtual environment |
| `node_modules/` | Local npm dependencies |
| `.runtime/api.pid` | Running local API process ID |
| `.runtime/api.url` | Current local API URL |
| `.runtime/api.out.log` | API stdout log |
| `.runtime/api.err.log` | API stderr log |
| `.runtime/pipeline-summary.txt` | Pipeline result summary |
| `postman/newman/` | Generated Newman collection and environment |
| `reports/newman/` | Newman JSON and JUnit reports |

These files are generated output or machine-specific state. They should not be committed.

# Integrate This Workflow into Your Own Project

You can reuse this local Build-Test-Deploy workflow in another FastAPI project. The goal is to copy the automation pattern, then change the project-specific names, import checks, Postman files, and health endpoint.

### Expected Project Shape

Your own project should have a structure similar to this:

```text
your-project/
  main.py
  requirements.txt
  package.json
  scripts/
  postman/
```

The scripts assume that the FastAPI app can be started with:

```powershell
python -m uvicorn main:app --host 127.0.0.1 --port 8080
```

If your app is not named `main.py`, or your FastAPI object is not named `app`, update the scripts wherever `main:app` appears.

Examples:

```text
main:app
app.main:app
src.server:api
```

### Files to Copy

Copy these automation files into your own project:

```text
scripts/build.ps1
scripts/test.ps1
scripts/deploy-local.ps1
scripts/stop-local.ps1
scripts/pipeline.ps1
scripts/verify-ngrok.ps1
scripts/export-postman-newman.mjs
package.json scripts section
```

If your project already has a `package.json`, copy only the useful scripts and dependencies instead of replacing the whole file.

Required npm scripts:

```json
{
  "scripts": {
    "cicd:local": "powershell -ExecutionPolicy Bypass -File ./scripts/pipeline.ps1",
    "verify:ngrok": "powershell -ExecutionPolicy Bypass -File ./scripts/verify-ngrok.ps1",
    "test:api": "powershell -ExecutionPolicy Bypass -File ./scripts/test.ps1",
    "deploy:local": "powershell -ExecutionPolicy Bypass -File ./scripts/deploy-local.ps1",
    "stop:local": "powershell -ExecutionPolicy Bypass -File ./scripts/stop-local.ps1"
  },
  "devDependencies": {
    "newman": "^6.2.2",
    "yaml": "^2.8.1"
  }
}
```

After editing `package.json`, run:

```powershell
npm install
```

### Update the Python Build Check

In `scripts/build.ps1`, find the import verification command.

This project uses:

```powershell
& $PythonInVenv -c "import main; assert main.app.title == 'Student Management API'; print('FastAPI app import OK')"
```

For your own project, change it to match your app.

Generic example:

```powershell
& $PythonInVenv -c "import main; assert main.app; print('FastAPI app import OK')"
```

If your module is `app.main`:

```powershell
& $PythonInVenv -c "from app.main import app; assert app; print('FastAPI app import OK')"
```

This check should prove that your application can be imported before the test or deploy phase starts.

### Update the Uvicorn App Target

In `scripts/test.ps1` and `scripts/deploy-local.ps1`, find:

```powershell
"main:app"
```

Replace it with your actual Uvicorn target.

For example:

```powershell
"app.main:app"
```

Use the same target you would use manually:

```powershell
uvicorn app.main:app --host 127.0.0.1 --port 8080
```

### Add a Health Endpoint

The automation expects this endpoint:

```text
GET /actuator/health
```

It should return JSON with:

```json
{
  "status": "UP"
}
```

If your project uses another health path, update these scripts:

```text
scripts/test.ps1
scripts/deploy-local.ps1
scripts/pipeline.ps1
scripts/verify-ngrok.ps1
```

Search for:

```text
/actuator/health
```

Then replace it with your own health path.

### Add or Export Postman Tests

This workflow tests the API with Newman. You need a Newman-compatible Postman collection and environment.

For this project, `scripts/export-postman-newman.mjs` converts local Postman YAML files into:

```text
postman/newman/API Testing.postman_collection.json
postman/newman/Test Subject 1.postman_environment.json
```

For your own project, choose one approach:

- Keep the converter script and adjust it to your Postman folder structure.
- Export a Postman collection and environment directly as JSON.
- Replace the collection and environment paths inside `scripts/test.ps1`.

In `scripts/test.ps1`, update these paths if your files have different names:

```powershell
$CollectionPath = Resolve-FromProjectRoot "postman\newman\API Testing.postman_collection.json"
$EnvironmentPath = Resolve-FromProjectRoot "postman\newman\Test Subject 1.postman_environment.json"
```

Your Postman environment should use a `baseUrl` variable, because the test script passes:

```powershell
--env-var "baseUrl=$BaseUrl"
```

That lets the same test collection run on port `8080`, port `8081`, or any other configured port.

### Update Ignored Generated Files

Add these generated paths to your own `.gitignore`:

```text
.venv/
node_modules/
.runtime/
reports/
postman/newman/
```

Keep source files, scripts, Postman source collections, and documentation committed. Keep generated runtime files out of Git.

### Verify the Integration

After copying and editing the workflow, test one phase at a time:

```powershell
npm install
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

```powershell
npm run test:api
```

```powershell
npm run deploy:local
```

```powershell
Invoke-RestMethod http://127.0.0.1:8080/actuator/health
```

```powershell
npm run stop:local
```

When each separate phase works, run the full workflow:

```powershell
npm run cicd:local
```

For ngrok verification, start ngrok first:

```powershell
ngrok http http://127.0.0.1:8080
```

Then pass the real public URL:

```powershell
npm run cicd:local -- -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"
```

### Integration Checklist

- `requirements.txt` contains all Python dependencies.
- `scripts/build.ps1` imports the correct Python module.
- `scripts/test.ps1` and `scripts/deploy-local.ps1` use the correct Uvicorn target.
- A health endpoint returns `{ "status": "UP" }`.
- Newman collection and environment paths are correct.
- Postman tests use `{{baseUrl}}`.
- `package.json` contains the automation scripts.
- `.gitignore` excludes generated local files.
- `npm run cicd:local` passes from a clean terminal.

## 11. Troubleshooting

If PowerShell blocks a script, run it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

Use the same pattern for `test.ps1`, `deploy-local.ps1`, `pipeline.ps1`, and `verify-ngrok.ps1`.

If port `8080` is busy, run the workflow on another port:

```powershell
npm run cicd:local -- -Port 8081
```

If the local API is already running, stop it:

```powershell
npm run stop:local
```

If ngrok verification returns `404 Not Found`, check that you passed the real ngrok URL. This is wrong:

```powershell
npm run cicd:local -- -Port 8081 -NgrokUrl "https://your-url.ngrok-free.dev"
```

This is correct when it matches the real URL shown by ngrok:

```powershell
npm run cicd:local -- -Port 8081 -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"
```

If ngrok returns `ERR_NGROK_3200`, the public endpoint is offline. Keep the ngrok terminal open, confirm the forwarding URL is still active, and rerun the command with the current URL.

If local health works but ngrok health fails, confirm both sides use the same port:

```text
ngrok forwarding: http://127.0.0.1:8081
pipeline port:   -Port 8081
```

## Quick Checklist

Use this checklist from a clean setup:

- Install Python, Node.js, npm, and PowerShell.
- Open a terminal in the project root.
- Run `npm install`.
- Run `powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1`.
- Run `npm run test:api`.
- Run `npm run deploy:local`.
- Open `http://127.0.0.1:8080/docs`.
- Check `http://127.0.0.1:8080/actuator/health`.
- Stop with `npm run stop:local`.

For public ngrok verification:

- Start ngrok with `ngrok http http://127.0.0.1:8080`.
- Copy the real ngrok forwarding URL.
- Run `npm run cicd:local -- -NgrokUrl "https://real-ngrok-url.ngrok-free.dev"`.
