# Azure CI/CD Demo

A minimal Node.js app deployed to **Azure App Service** via **GitHub Actions**,
using **OIDC federated login** (no stored secrets/passwords) and a
**staging → production deployment slot swap** for zero-downtime releases.

## Architecture

```
push to main
     │
     ▼
GitHub Actions: build job (npm ci, test, zip)
     │
     ▼
GitHub Actions: deploy-staging job (deploy zip to "staging" slot)
     │
     ▼
GitHub Actions: swap-to-production job (swap staging <-> production)
```

## Setup steps

### 1. Create the GitHub repo
Push this folder to a new GitHub repo (e.g. `azure-cicd-demo`).

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<your-username>/azure-cicd-demo.git
git push -u origin main
```

### 2. Log into Azure CLI locally
```bash
az login
```

### 3. Edit and run the infra script
Open `infra/setup.sh` and change:
- `GITHUB_ORG` → your GitHub username/org
- `GITHUB_REPO` → your repo name (if different)

Then run it:
```bash
chmod +x infra/setup.sh
./infra/setup.sh
```

This creates:
- A resource group
- An App Service Plan (Linux, B1 tier)
- A Web App running Node 20
- A "staging" deployment slot
- An Azure AD App Registration with **federated credentials** trusting your
  GitHub repo's `main` branch (this is what lets GitHub Actions log into Azure
  without any stored password/secret — it's short-lived token exchange)
- A Contributor role assignment, scoped only to your resource group (not the
  whole subscription — principle of least privilege)

**Copy the output values** — you'll need them in the next step.

### 4. Add GitHub repo secrets
In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**

Add these three (from the script's output):
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### 5. Update the workflow file
In `.github/workflows/deploy.yml`, change:
```yaml
AZURE_WEBAPP_NAME: 'CHANGE-ME-TO-YOUR-WEBAPP-NAME'
```
to the actual web app name the script printed out.

### 6. (Optional but recommended) Add a manual approval gate
In GitHub: **Settings → Environments → production → Required reviewers**
Add yourself. Now the `swap-to-production` job will pause and wait for you to
click "Approve" before it goes live — this mirrors real-world release gates.

### 7. Push and watch it run
```bash
git add .
git commit -m "Update webapp name"
git push
```
Go to the **Actions** tab in GitHub and watch the pipeline run.

### 8. Verify
Visit `https://<your-webapp-name>.azurewebsites.net` — you should see the demo page.

## What this teaches you (and maps to AZ-104)

| Concept | AZ-104 relevance |
|---|---|
| Resource Groups | Core resource management domain |
| App Service Plans & tiers | Compute domain — scaling, pricing tiers |
| Deployment slots | App Service management, zero-downtime deploys |
| Azure AD App Registrations | Identity domain |
| RBAC (Contributor, scoped to RG) | Governance & identity domain — least privilege |
| OIDC federated credentials | Modern secretless auth pattern (real-world best practice) |

## Cleanup (avoid ongoing charges)
```bash
az group delete --name rg-cicd-demo --yes --no-wait
```
This deletes everything in one shot (App Service, plan, slot). You may also want
to delete the App Registration:
```bash
az ad app delete --id <APP_ID>
```

## Next steps / stretch goals
- Add real tests (Jest) instead of the placeholder `npm test`
- Add a `dev`/`feature-branch` workflow that deploys PRs to an ephemeral slot
- Redo this same pipeline with Python/Flask to compare
- Swap App Service for AKS once you're comfortable (bigger leap: containers,
  Kubernetes manifests, `kubectl`, container registry)
- Add Application Insights for monitoring/logging
