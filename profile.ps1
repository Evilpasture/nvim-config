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
        Write-Host " [✓] GitHub Identity Verified: @$CurrentGHUser" -ForegroundColor Green
        if ($null -eq $CommandArgs) { gsudo } else { gsudo $CommandArgs }
    } else {
        Write-Host " [!] ACCESS DENIED: User '@$CurrentGHUser' is not authorized." -ForegroundColor Red
    }
}


# ==========================================================================
# MASTER NERD-FONT PROMPT (Optimized)
# ==========================================================================
function prompt {
    $lastStatus = $?
    $shortPath = $(Get-Location).Path.Replace($env:USERPROFILE, "~")

    # Fast Git Check (avoiding heavy objects)
    $gitInfo = ""
    if (git rev-parse --is-inside-work-tree 2>$null) {
        $branch = git branch --show-current
        $dirty = if (git status --porcelain) { "*" } else { "" }
        $gitColor = if ($dirty) { "Red" } else { "Yellow" }
        $gitInfo = "  $branch$dirty"
    }

    # Line 1
    Write-Host "`n  󰉋 $shortPath" -NoNewline -ForegroundColor Cyan
    if ($gitInfo) { Write-Host $gitInfo -ForegroundColor $gitColor }
    
    # Line 2: Status Icon
    $statusIcon = if ($lastStatus) { "✔" } else { "✘" }
    $statusColor = if ($lastStatus) { "Green" } else { "Red" }
    Write-Host "`n  $statusIcon" -NoNewline -ForegroundColor $statusColor
    
    return " ❯ "
}

# Aliases
Set-Alias v nvim
function reload { . $PROFILE }
function dash { Show-Dashboard }

# Run dashboard on startup
Show-Dashboard

