#!/bin/bash
# ============================================================
# Azure CI/CD Demo - Infrastructure Setup Script
# Run this once, locally, after `az login`
# ============================================================
set -e

# ---- EDIT THESE VARIABLES ----
RESOURCE_GROUP="rg-cicd-demo"
LOCATION="eastus"
APP_SERVICE_PLAN="asp-cicd-demo"
WEBAPP_NAME="cicd-demo-$RANDOM"          # must be globally unique - script randomizes it
GITHUB_ORG="your-github-username"        # <-- CHANGE THIS
GITHUB_REPO="azure-cicd-demo"            # <-- CHANGE THIS if you name your repo differently
# --------------------------------

echo "=================================================="
echo "Web app name will be: $WEBAPP_NAME"
echo "Save this name - you'll need it for the GitHub Actions workflow!"
echo "=================================================="

# 1. Create Resource Group
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# 2. Create App Service Plan (Linux, B1 tier - required because deployment slots
#    are NOT available on the Free F1 tier. B1 costs ~$13/month - delete when done.)
az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP" \
  --sku B1 \
  --is-linux

# 3. Create the Web App with Node 20 runtime
az webapp create \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$APP_SERVICE_PLAN" \
  --runtime "NODE:20-lts"

# 4. Create a "staging" deployment slot (requires B1 tier or higher, not Free)
az webapp deployment slot create \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --slot staging

# 5. Create an Azure AD App Registration for GitHub OIDC login
APP_NAME="github-oidc-$WEBAPP_NAME"
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
echo "Created App Registration with App ID: $APP_ID"

# 6. Create a Service Principal for the App Registration
az ad sp create --id "$APP_ID"

# 7. Get Subscription and Tenant IDs
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# 8. Assign Contributor role scoped to the resource group (least privilege - not subscription-wide)
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

# 9. Create Federated Credential trusting your GitHub repo's main branch
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-main-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

echo ""
echo "=================================================="
echo "DONE. Add these as GitHub repo secrets (Settings > Secrets > Actions):"
echo "AZURE_CLIENT_ID:       $APP_ID"
echo "AZURE_TENANT_ID:       $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""
echo "And note your Web App name for the workflow file:"
echo "AZURE_WEBAPP_NAME:     $WEBAPP_NAME"
echo "=================================================="
