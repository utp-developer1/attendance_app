# Run this script locally AFTER installing Git and GitHub CLI (gh)
# Usage: Right-click -> Run with PowerShell, or run from terminal:
#   cd C:\attendance_app
#   .\scripts\create_and_push_repo.ps1 -RepoName attendance_app -Visibility private

param(
  [string]$RepoName = "attendance_app",
  [ValidateSet('public','private')]
  [string]$Visibility = 'private'
)

Write-Host "Checking required tools..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "Git is not installed or not on PATH. Install Git from https://git-scm.com/downloads and rerun."
  exit 1
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Error "GitHub CLI (gh) is not installed or not on PATH. Install from https://cli.github.com/ and run 'gh auth login' before rerunning."
  exit 1
}

# Ensure gh is authenticated
$auth = gh auth status --hostname github.com 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "Please run 'gh auth login' and authenticate, then re-run this script." -ForegroundColor Yellow
  exit 1
}

# Initialize git repo if needed
if (-not (Test-Path .git)) {
  git init
}

git add .

try {
  git commit -m "Initial commit (workspace snapshot)"
} catch {
  Write-Host "Commit may have failed (possible no changes or user.name/email not set): $_" -ForegroundColor Yellow
}

# Create GitHub repo and push
Write-Host "Creating GitHub repo '$RepoName' (visibility: $Visibility) and pushing..."
gh repo create $RepoName --$Visibility --source=. --remote=origin --push

if ($LASTEXITCODE -eq 0) {
  Write-Host "Repository created and pushed. Remote origin set to:"
  git remote -v
} else {
  Write-Error "gh repo create failed. Please run the command manually: gh repo create $RepoName --$Visibility --source=. --remote=origin --push"
}
