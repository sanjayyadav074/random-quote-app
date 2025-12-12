# Random Quote App: Azure + Terraform

## Overview

This is a simple, production-style Random Quote web application built to demonstrate how to deploy a secure, cloud-native app on Microsoft Azure using Terraform. The app connects to an Azure SQL Database containing famous quotes and returns one random quote each time the site is accessed.

While the application itself is intentionally small, the real focus here is on clean infrastructure design, security best practices, and deployment hygiene rather than feature complexity. Every decision has been made deliberately and is documented below.

## Live Application

You can access the running application here:

👉 https://quotesapp-web-euw2.azurewebsites.net

Health check endpoint:

👉 https://quotesapp-web-euw2.azurewebsites.net/health

## Architecture

At a high level, here's what we're building:

- **Frontend / App**: Node.js + Express (a single, lightweight service)
- **Database**: Azure SQL Database
- **Hosting**: Azure App Service (Linux)
- **Secrets Management**: Azure Key Vault
- **Infrastructure as Code**: Terraform
- **Deployment**: ZIP deploy to App Service
- **Region**: Central US

All infrastructure is provisioned using Terraform, and application code is deployed separately to keep concerns clean and manageable.

## What the App Does

- **Visiting `/`**: Returns a random quote from the database
- **Visiting `/health`**: Returns application and database health status (HTTP 200 if everything is healthy)
- **Quote Fetching**: Uses an ID-based random offset approach instead of `ORDER BY NEWID()` for better scalability

## Database Design

The database is kept intentionally simple with a single table:

```sql
CREATE TABLE Quotes (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  Author NVARCHAR(100) NOT NULL,
  Text NVARCHAR(500) NOT NULL
);
```

Quotes are pre-seeded into the database at provisioning time.

## Security & PII Handling

Although the data itself isn't real PII, we treat all data as critical and confidential, per best practices:

- **No hard-coded credentials**: Database credentials are never in the code
- **Key Vault for secrets**: The SQL connection string is stored only in Azure Key Vault
- **App Service integration**: The web app reads secrets using Key Vault references
- **TLS encryption**: All SQL connections use encrypted TLS
- **Remote state**: Terraform state is stored remotely to avoid leaking infrastructure metadata

This approach ensures that even if the repository is compromised, sensitive data remains protected.

## Infrastructure (Terraform)

Terraform provisions the entire cloud environment:

- Resource Group
- Azure App Service Plan (B1)
- Azure Linux Web App
- Azure SQL Server + Database
- Azure Key Vault
- Firewall rules (Azure services allowed)
- Remote Terraform backend (Azure Blob Storage)

Terraform state is stored remotely with locking enabled, which is the correct approach for any real team environment.

## Deployment Flow

Here's how the app gets from your laptop to Azure:

1. Application code lives in the `app/` folder
2. Dependencies (`node_modules`) are excluded from the deployment package
3. App Service installs dependencies during deployment
4. Deployment is done via: `az webapp deploy --src-path app.zip`

This keeps the artifact clean and production-friendly. You don't ship node_modules; you let Azure handle that.

## Improvements Implemented

These enhancements were actively implemented to make the app more production-aware:

### Efficient Random Query
Replaced `ORDER BY NEWID()` with a `COUNT(*) + OFFSET/FETCH` approach. This scales better and doesn't hammer the database with expensive operations.

### Secure Secret Handling
The SQL connection string is stored in Key Vault, not in code or Terraform variables. The app reads it at runtime.

### Deployment Hygiene
The `node_modules` folder is excluded from the ZIP; dependencies are installed server-side by App Service.

### Remote Terraform State
State is stored in Azure Blob Storage with locking enabled. This prevents state conflicts in a team environment.

### Application Structure
- `/health` endpoint for monitoring
- Basic request logging to understand what's happening
- Global error handling to gracefully handle failures
- Minimal test scaffold using Node's built-in `--test` runner

These changes make the app production-aware without unnecessary complexity.

## Known Trade-offs & Design Decisions

The following were intentionally not implemented due to free-tier constraints and scope, but they're well understood and documented:

### 1. High Availability

**What we have**: Single region, single App Service Plan (B1), single SQL Database

**What production needs**: 
- Auto-scaling across multiple instances
- Multi-region App Services
- Azure Front Door for global load balancing
- SQL geo-replication

### 2. Least-Privilege Database Access

**What we have**: The app connects using a SQL admin login stored securely in Key Vault

**What production needs**:
- A dedicated SQL user with only SELECT permissions, or
- Azure AD authentication using Managed Identity (passwordless)

### 3. SQL Firewall Configuration

**What we have**: The SQL server currently allows Azure services (0.0.0.0) for simplicity

**What production needs**:
- Restriction to App Service outbound IPs, or
- Private Endpoint + VNet integration for true network isolation

### 4. Advanced Observability

**What we have**: Lightweight application logging

**What production needs**:
- Structured logging (Application Insights)
- Metrics and alerts
- Distributed tracing

## Why This Design?

This project is intentionally small but realistic. Every shortcut taken is deliberate and documented. The goal is to demonstrate:

- **Clear thinking**: Why each component exists
- **Secure defaults**: Security considerations are built in from the start
- **Production awareness**: Understanding real concerns like state management, secrets, and scalability
- **Honest trade-offs**: Ability to explain what's not done and why, and when it would matter

This mirrors how real engineering decisions are made under constraints. A Reader should be able to read this repository and understand not just what was built, but why each decision was made.

## How to Run Locally (Optional)

If you want to run the app locally for development:

```bash
cd app
npm install
npm start
```

Note: This requires a valid `SQL_CONNECTION_STRING` environment variable pointing to your database.

## Final Notes

This project is not meant to be flashy. It's meant to be correct, secure, and explainable. The focus is on realistic, production-style engineering decisions made within reasonable constraints.