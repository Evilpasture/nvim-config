# ==========================================================================
# RE-WRITTEN DASHBOARD (Python Caller)
# ==========================================================================
$PYTHON_DASH_PATH = "$HOME\AppData\Local\nvim\dashboard.py" # Update this path!

function Show-Dashboard {
    Clear-Host
    if (Test-Path $PYTHON_DASH_PATH) {
        python $PYTHON_DASH_PATH
    } else {
        Write-Host "Dashboard script not found at $PYTHON_DASH_PATH" -ForegroundColor Red
    }
}


# ==========================================================================
# GITHUB-GUARDED SUDO
# ==========================================================================
function sudo {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        $CommandArgs
    )

    # 1. Check if we are already Admin
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($IsAdmin) {
        if ($null -eq $CommandArgs) {
            Write-Host " [!] Already running as Administrator." -ForegroundColor Cyan
        } else {
            # Run the command directly since we are already admin
            & $CommandArgs[0] $CommandArgs[1..$CommandArgs.Length]
        }
        return
    }

    # 2. GitHub Identity Check
    $AuthorizedUser = "Evilpasture" 
    $CurrentGHUser = $(gh config get -h github.com user 2>$null)
    if (-not $CurrentGHUser) { $CurrentGHUser = $(gh api user --jq .login 2>$null) }

    if ($CurrentGHUser -eq $AuthorizedUser) {
        Write-Host "[✓] GitHub Identity Verified: @$CurrentGHUser" -ForegroundColor Green
        if ($null -eq $CommandArgs) { gsudo } else { gsudo $CommandArgs }
    } else {
        Write-Host " [!] ACCESS DENIED: User '@$CurrentGHUser' is not authorized." -ForegroundColor Red
    }
}


# ==========================================================================
# MASTER NERD-FONT PROMPT (Hardened for PS 5.1)
# ==========================================================================
function prompt {
    $lastStatus = $?
    $timeStr = Get-Date -Format "HH:mm:ss"
    $shortPath = $(Get-Location).Path.Replace($env:USERPROFILE, "~")

    # 1. Git Logic
    $gitInfo = ""
    $null = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0) {
        $branch = $(git branch --show-current 2>$null).Trim()
        $dirty = if (git status --porcelain 2>$null) { "*" } else { "" }
        $gitColor = if ($dirty) { "Red" } else { "Magenta" }
        $gitInfo = "  $branch$dirty"
    }

    # 2. Status Logic
    $statusColor = if ($lastStatus) { "Green" } else { "Red" }
    $statusIcon = if ($lastStatus) { "󰄬" } else { "󰅙" }

    # 3. Draw Line 1 (The Frame and Info)
    Write-Host "`n┌─[" -NoNewline -ForegroundColor Gray
    Write-Host "$timeStr" -NoNewline -ForegroundColor DarkGray
    Write-Host "]─(" -NoNewline -ForegroundColor Gray
    Write-Host "󰉋 $shortPath" -NoNewline -ForegroundColor Cyan
    if ($gitInfo) { 
        Write-Host ")─(" -NoNewline -ForegroundColor Gray
        Write-Host "$gitInfo" -NoNewline -ForegroundColor $gitColor 
    }
    Write-Host ")" -ForegroundColor Gray

    # 4. Draw Line 2 (The Input)
    Write-Host "└─" -NoNewline -ForegroundColor Gray
    Write-Host "$statusIcon " -NoNewline -ForegroundColor $statusColor
    
    return "❯ "
}

# Aliases
Set-Alias v nvim
function reload { . $PROFILE }
function dash { Show-Dashboard }

# Run dashboard on startup
Show-Dashboard

