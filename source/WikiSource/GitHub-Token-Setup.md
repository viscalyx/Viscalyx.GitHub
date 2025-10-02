# GitHub Token Setup for Integration Tests

This document explains how to create and configure a GitHub personal access token
to avoid rate limiting issues when running integration tests for the
Viscalyx.GitHub PowerShell module.

## Why Use a GitHub Token?

GitHub API has rate limits for unauthenticated requests:

- **Anonymous requests**: 60 requests per hour per IP address
- **Authenticated requests**: 5,000 requests per hour per user

Integration tests make multiple API calls to GitHub and can quickly exceed the
anonymous rate limit, resulting in errors like:

- `Failed to retrieve GitHub API data: The remote server returned an error:
  (403) Forbidden.`
- `Failed to retrieve GitHub API data: Response status code does not indicate
  success: 403 (rate limit exceeded).`

## Creating a GitHub Token - Fine-grained Personal Access Token

Fine-grained tokens provide more precise permission control and are the
recommended approach for new tokens.

1. **Navigate to GitHub Settings**:
   - Go to [GitHub.com](https://github.com) and sign in
   - Click your profile picture → **Settings**
   - In the left sidebar, click **Developer settings**
   - Click **Personal access tokens** → **Fine-grained tokens**

1. **Generate New Token**:
   - Click **Generate new token**
   - Fill in the required fields:
     - **Token name**: `Viscalyx.GitHub Integration Tests` (or similar name)
     - **Expiration**: Choose an appropriate expiration (90 days recommended)
     - **Description**: "This is used by integration tests in Viscalyx.Github
       to avoid errors against GitHub API. It has only read access to Viscalyx.GitHub."

1. **Resource Owner**:
   - Select the GitHub organization as the resource owner

1. **Configure Repository Access**:
   - **Repository access**: Select **Only select repositories**
   - Add the `Viscalyx.GitHub` repository
     - This allows the token to access only this repository for read operations

1. **Set Permissions**:
   - Under **Repository permissions**, set:
     - **Contents**: **Read** (to access repository files and releases)
     - **Metadata**: **Read** (to access basic repository information)
   - **Do not select any other permissions** - the token only needs read access

1. **Generate and Save**:
   - Click **Generate token**
   - **Important**: Copy the token immediately and save it securely
   - You won't be able to see the token again after leaving this page

## Using the Token Locally

### For Local Development

1. **Set Environment Variable**:

   **Windows (PowerShell)**:

   ```powershell
   $env:GITHUB_TOKEN = 'ghp_your_token_here'
   ```

   **Windows (Command Prompt)**:

   ```cmd
   set GITHUB_TOKEN=ghp_your_token_here
   ```

   **macOS/Linux (Bash/Zsh)**:

   ```bash
   export GITHUB_TOKEN='ghp_your_token_here'
   ```

1. **Run Integration Tests**:

   ```powershell
   .\build.ps1 -Tasks test
   ```

   The integration tests will automatically detect and use the `GITHUB_TOKEN`
   environment variable when available.

### For Persistent Configuration

To avoid setting the environment variable each time, you can add it to your
shell profile:

**PowerShell Profile** (`$PROFILE`):

```powershell
$env:GITHUB_TOKEN = "ghp_your_token_here"
```

**Bash Profile** (`~/.bashrc` or `~/.bash_profile`):

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

**Zsh Profile** (`~/.zshrc`):

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

## Using the Token in CI/CD

### Azure Pipelines

1. **Add Repository Secret**:
   - Go to your Azure DevOps project
   - Navigate to **Pipelines** → **Library**
   - Create a new variable group or add to existing one
   - Add variable: `GITHUB_TOKEN_INTEGRATION` with your token value
   - Mark it as **secret**

1. **Update Pipeline Configuration**:

   ```yaml
   - task: PowerShell@2
     displayName: 'Run Integration Tests'
     inputs:
       filePath: './build.ps1'
       arguments: '-tasks test'
       pwsh: true
     env:
       GITHUB_TOKEN: $(GITHUB_TOKEN_INTEGRATION)
   ```

### GitHub Actions

1. **Add Repository Secret**:
   - Go to your repository on GitHub
   - Click **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `GITHUB_TOKEN_INTEGRATION`
   - Value: Your token
   - Click **Add secret**

1. **Update Workflow Configuration**:

   ```yaml
   - name: Run Integration Tests
     run: ./build.ps1 -Tasks test
     shell: pwsh
     env:
       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN_INTEGRATION }}
   ```

## Testing Token Configuration

You can verify your token is working by running a simple test:

```powershell
# Set your token
$env:GITHUB_TOKEN = "ghp_your_token_here"

# Test a single integration test
Import-Module .\output\builtModule\Viscalyx.GitHub\*\Viscalyx.GitHub.psd1
Get-GitHubRelease -OwnerName 'PowerShell' -RepositoryName 'PowerShell' `
  -Latest -Token (ConvertTo-SecureString $env:GITHUB_TOKEN -AsPlainText -Force)
```

If successful, you should see release information without any rate limiting
errors.

## Additional Resources

- [Fine-grained Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token#creating-a-fine-grained-personal-access-token)
