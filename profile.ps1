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
    $timeStr = Get-Date -Format "HH:mm"
    
    # 1. ANSI Color Definitions (256-color palette)
    $E = [char]27
    $Reset = "$E[0m"
    $Bold  = "$E[1m"
    
    # Foreground Colors
    $DimGray   = "$E[38;5;240m"
    $MidGray   = "$E[38;5;244m"
    $Gold      = "$E[38;5;214m"
    $DeepCyan  = "$E[38;5;39m"
    $SoftGreen = "$E[38;5;78m"
    $SoftRed   = "$E[38;5;203m"
    $MutedMag  = "$E[38;5;170m"
    
    # Backgrounds
    $BarBG     = "$E[48;5;235m" # Recessed dark bar
    $TimeBG    = "$E[48;5;238m" # Slightly lighter for the time pill
    
    # 2. Path Logic
    $fullPath = (Get-Location).Path
    $drive = $fullPath.Substring(0, 2)
    $restOfPath = $fullPath.Substring(2).Replace($env:USERPROFILE, "~")
    if ($restOfPath -eq "") { $restOfPath = "\" }

    # 3. Git Status (Optimized)
    $gitInfo = ""
    $null = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0) {
        $branch = $(git branch --show-current 2>$null).Trim()
        $dirty = if (git status --porcelain 2>$null) { " $SoftRed󱈸" } else { "" }
        $gitInfo = " $MidGray $MutedMag$branch$dirty"
    }

    # 4. Construct Line 1 (The Pill & Information Bar)
    #  and  create the rounded container
    $line1 = "`n$DimGray$TimeBG$Bold $timeStr $Reset$DimGray" # Time Pill
    $line1 += " $Gold󰋊 $drive$Reset"                          # Drive
    $line1 += " $DeepCyan󰉋 $restOfPath$Reset"                 # Path
    $line1 += "$gitInfo$Reset"                                # Git

    Write-Host $line1

    # 5. Construct Line 2 (The Input)
    $statusColor = if ($lastStatus) { $SoftGreen } else { $SoftRed }
    $statusIcon  = if ($lastStatus) { "󰄬" } else { "󰅙" }
    
    # Draw the industrial elbow connector
    Write-Host "$DimGray└─$statusColor$statusIcon$Reset " -NoNewline
    
    return "$Bold❯$Reset "
}

# Aliases
Set-Alias v nvim
function kill-clicker {Stop-Process -Name clicker}
function reload { . $PROFILE }
function dash { Show-Dashboard }
function activate {
    $venvPath = ".\.venv\Scripts\Activate.ps1"
    
    if (Test-Path $venvPath) {
        & $venvPath
        # Clean success message using your prompt's color palette
        Write-Host "󱈸 " -NoNewline -ForegroundColor Cyan
        Write-Host "Environment activated: " -NoNewline -ForegroundColor Gray
        Write-Host ".venv" -ForegroundColor Green
    } else {
        # Graceful failure - no red text, just a helpful hint
        Write-Host "󰋊 " -NoNewline -ForegroundColor Yellow
        Write-Host "No .venv found in " -NoNewline -ForegroundColor Gray
        Write-Host "$(Get-Location)" -ForegroundColor Magenta
        Write-Host "Hint: Are you in the project root?" -ForegroundColor DarkGray
    }
}

# Run dashboard on startup
Show-Dashboard

