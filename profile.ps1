$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
# MASTER NERD-FONT PROMPT (Bulletproof Edition)
# ==========================================================================
function prompt {
    # Capture status of the last command immediately
    $lastStatus = $?
    $timeStr = Get-Date -Format "HH:mm"
    
    # 1. Colors
    $E = [char]27
    $Reset = "$E[0m"
    $Bold  = "$E[1m"
    
    $DimGray   = "$E[38;5;240m"
    $MidGray   = "$E[38;5;244m"
    $Gold      = "$E[38;5;214m"
    $DeepCyan  = "$E[38;5;39m"
    $SoftGreen = "$E[38;5;78m"
    $SoftRed   = "$E[38;5;203m"
    $MutedMag  = "$E[38;5;170m"
    
    $BarBG     = "$E[48;5;235m"
    $TimeBG    = "$E[48;5;238m"
    
    # 2. Path Logic (Protected)
    try {
        $fullPath = (Get-Location).Path
        $userProfile = $env:USERPROFILE

        # Case-Insensitive Check for Home Directory
        if ($fullPath.StartsWith($userProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
            # Use Substring based on profile length to handle casing differences safely
            $relPath = $fullPath.Substring($userProfile.Length)
            if ($relPath -eq "") { $relPath = "\" }
            
            $drive = "~"
            $restOfPath = $relPath
        }
        else {
            # Safely get drive letter (or first 2 chars)
            if ($fullPath.Length -ge 2) {
                $drive = $fullPath.Substring(0, 2)
                $restOfPath = $fullPath.Substring(2)
            } else {
                # Fallback for root/weird paths
                $drive = $fullPath
                $restOfPath = ""
            }
            if ($restOfPath -eq "") { $restOfPath = "\" }
        }
    } catch {
        # Fallback if path logic explodes
        $drive = "FS"
        $restOfPath = (Get-Location).Path
    }

    # 3. Git Status (Wrapped in Try/Catch to prevent crashes)
    $gitInfo = ""
    try {
        # Fast check: Is this a git repo?
        # We check specific git files OR fallback to rev-parse
        if (Test-Path -Path .git -PathType Container -ErrorAction SilentlyContinue) {
            $isGit = $true
        } else {
            # This captures stderr to null so it doesn't print "fatal:..."
            $isGit = [bool](git rev-parse --is-inside-work-tree 2>$null)
        }

        if ($isGit) {
            # A. Get Branch
            $branchObj = git branch --show-current 2>$null
            if ([string]::IsNullOrWhiteSpace($branchObj)) {
                $shortSha = git rev-parse --short HEAD 2>$null
                $branch = "HEAD:$shortSha"
            } else {
                $branch = $branchObj.Trim()
            }

            # B. Check for Heavy Repos (LLVM, Chromium, etc)
            $isHeavyRepo = $fullPath -match "llvm-project" -or $fullPath -match "chromium"
            
            $dirty = ""
            if (-not $isHeavyRepo) {
                # Fast status check
                $status = git status --porcelain --untracked-files=no 2>$null
                if ($status) { $dirty = " $SoftRed󱈸" }
            } else {
                # Skip check for heavy repos
                $dirty = " $DimGray󰈸?" 
            }
            
            $gitInfo = " $MidGray $MutedMag$branch$dirty"
        }
    } catch {
        # If Git is not installed or crashes, do nothing, just show empty git string
        $gitInfo = ""
    }

    # 4. Draw Line 1
    $line1 = "`n$DimGray$TimeBG$Bold $timeStr $Reset$DimGray" 
    $line1 += " $Gold󰋊 $drive$Reset"                          
    $line1 += " $DeepCyan󰉋 $restOfPath$Reset"                 
    $line1 += "$gitInfo$Reset"                                

    Write-Host $line1

    # 5. Draw Line 2
    $statusColor = if ($lastStatus) { $SoftGreen } else { $SoftRed }
    $statusIcon  = if ($lastStatus) { "󰄬" } else { "󰅙" }
    
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
function gohome {Set-Location $HOME\AppData\Local\nvim}
function conf { nvim $HOME\AppData\Local\nvim\init.lua }
# Or to open Oil in that dir:
function nconf {
    # Replace backslashes with forward slashes for Lua compatibility
    $luaPath = ($HOME + "\AppData\Local\nvim").Replace("\", "/")
    nvim "+lua require('oil').open('$luaPath')"
}

# ==========================================================================
# GITHUB PR TRACKER (Open & Closed)
# ==========================================================================
function Get-MyPRs {
    param(
        [Parameter(Mandatory=$false)]
        [int]$Limit = 10
    )

    # 1. Theme Colors
    $E = [char]27
    $Reset     = "$E[0m"
    $MutedMag  = "$E[38;5;170m"
    $SoftGreen = "$E[38;5;78m"
    $DeepCyan  = "$E[38;5;39m"
    $SoftRed   = "$E[38;5;203m"
    $DimGray   = "$E[38;5;240m"
    $Gold      = "$E[38;5;214m"
    $Cyan      = "$E[38;5;39m"
    $White     = "$E[38;5;255m"

    Write-Host "`n  $Gold RECENT PULL REQUESTS (Global)$Reset"
    Write-Host "  $DimGray──────────────────────────────────────────────────────────────────────────────────────────$Reset"

    # 2. Fetch data 
    $rawJson = gh search prs --author "@me" --limit $Limit --json number,title,state,updatedAt,repository,author 2>$null
    
    if (-not $rawJson) {
        Write-Host "  $DimGray (No PRs found or GitHub offline)$Reset"
    } else {
        $prs = $rawJson | ConvertFrom-Json
        $myHandle = $prs[0].author.login # Get handle from the first result

        $mergedCount = 0
        foreach ($pr in $prs) {
            # --- LOGIC: Authorship / Collaboration ---
            $repoOwner = $pr.repository.nameWithOwner.Split('/')[0]
            if ($pr.state -eq "MERGED") { $mergedCount++ }
            
            if ($repoOwner -eq $myHandle) {
                $collabIcon = ""
                $collabType = "Solo (@$myHandle)"
            } else {
                $collabIcon = ""
                $collabType = "Contrib (@$repoOwner)"
            }

            # --- LINE 1: ID, REPO, TITLE ---
            $id    = "#$($pr.number)".PadRight(6)
            $repo  = "$($pr.repository.name)".ToUpper().PadRight(18)
            $title = $pr.title 
            
            Write-Host "  $MutedMag$id$Reset $Cyan$repo$Reset $White$title$Reset"

            # --- LINE 2: METADATA ---
            $stateColor = switch ($pr.state) {
                "OPEN"   { $SoftGreen }
                "MERGED" { $DeepCyan }
                default  { $SoftRed }
            }
            $state = $pr.state.ToLower().PadRight(7)
            $date  = [DateTime]::Parse($pr.updatedAt).ToString("dd MMM yyyy")

            # Indent exactly 9 spaces to align under Repo Name
            Write-Host "         $stateColor$state$Reset" -NoNewline
            Write-Host " $DimGray│  $collabIcon $collabType  │  $date$Reset"
            Write-Host "" 
        }
        
        # --- SUMMARY FOOTER ---
        Write-Host "  $DimGray──────────────────────────────────────────────────────────────────────────────────────────$Reset"
        Write-Host "  $DimGray$Reset$DeepCyan $mergedCount Merged PRs $Reset$DimGray$Reset $DimGray showing last $Limit$Reset"
    }
    Write-Host ""
}

# Alias for quick access
Set-Alias prs Get-MyPRs

# ==========================================================================
# PROJECT JUMPER
# ==========================================================================
function p {
    param($Name)
    if (-not $Name) { Set-Location "E:\"; return }
    
    $BaseDir = "E:\Projects"
    # Search for directories containing the string, sorted by last write time
    $Match = Get-ChildItem $BaseDir -Directory | 
             Where-Object { $_.Name -like "*$Name*" } | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -First 1

    if ($Match) { 
        Set-Location $Match.FullName
        Write-Host "󱈸 Switching to: " -NoNewline -ForegroundColor Gray
        Write-Host "$($Match.Name)" -ForegroundColor Cyan
        v . 
    }
    else { 
        Write-Host "󰅙 No project matching '$Name' found in $BaseDir" -ForegroundColor Red 
    }
}

# Run dashboard on startup
Show-Dashboard

