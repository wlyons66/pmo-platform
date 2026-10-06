#Requires -Modules PnP.PowerShell
<#
.SYNOPSIS
    Provisions the BMC PMO Platform master SharePoint site structure.
.DESCRIPTION
    Creates libraries, folders, seed data uploads, Solution Registry list,
    and enforces governance column schema at /sites/PMO-Platform.
.NOTES
    Prerequisites:
      Install-Module PnP.PowerShell -Scope CurrentUser
    Run once per tenant. Re-running is safe — existing items are skipped.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TenantUrl,          # e.g. https://contoso.sharepoint.com

    [Parameter(Mandatory)]
    [string]$SiteUrl,            # e.g. https://contoso.sharepoint.com/sites/PMO-Platform

    [string]$SeedDataPath = $PSScriptRoot   # folder containing the CSV seed files
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ─── 1. CONNECT ──────────────────────────────────────────────────────────────
Write-Host "`n[1/6] Connecting to SharePoint..." -ForegroundColor Cyan
Connect-PnPOnline -Url $SiteUrl -Interactive

# ─── 2. ENSURE SITE EXISTS ───────────────────────────────────────────────────
Write-Host "[2/6] Verifying site exists at $SiteUrl" -ForegroundColor Cyan
try {
    $web = Get-PnPWeb
    Write-Host "      Site found: $($web.Title)" -ForegroundColor Green
}
catch {
    Write-Warning "Site not found. Creating communication site at $SiteUrl ..."
    Connect-PnPOnline -Url $TenantUrl -Interactive
    New-PnPSite -Type CommunicationSite `
                -Title "PMO Platform" `
                -Url $SiteUrl `
                -Description "BMC PMO master governance & solution platform" | Out-Null
    Connect-PnPOnline -Url $SiteUrl -Interactive
    Write-Host "      Site created." -ForegroundColor Green
}

# ─── 3. DOCUMENT LIBRARIES & FOLDERS ─────────────────────────────────────────
Write-Host "[3/6] Provisioning document libraries and folders..." -ForegroundColor Cyan

function Ensure-Library {
    param([string]$Name, [string]$Description = "")
    $lib = Get-PnPList -Identity $Name -ErrorAction SilentlyContinue
    if ($null -eq $lib) {
        New-PnPList -Title $Name -Template DocumentLibrary -OnQuickLaunch | Out-Null
        Write-Host "      Created library: $Name" -ForegroundColor Green
    } else {
        Write-Host "      Library exists:  $Name" -ForegroundColor DarkGray
    }
}

function Ensure-Folder {
    param([string]$Library, [string]$FolderPath)
    try {
        Resolve-PnPFolder -SiteRelativePath "$Library/$FolderPath" | Out-Null
        Write-Host "      Folder exists:   $Library/$FolderPath" -ForegroundColor DarkGray
    }
    catch {
        Add-PnPFolder -Name $FolderPath -Folder $Library | Out-Null
        Write-Host "      Created folder:  $Library/$FolderPath" -ForegroundColor Green
    }
}

# SolutionPackages library
Ensure-Library -Name "SolutionPackages"
foreach ($folder in @("Draft","Approved","Deprecated","Archive")) {
    Ensure-Folder -Library "SolutionPackages" -FolderPath $folder
}

# SeedData library
Ensure-Library -Name "SeedData"

# Runbooks library
Ensure-Library -Name "Runbooks"
Ensure-Folder -Library "Runbooks" -FolderPath "ReleaseNotes"

# ─── 4. UPLOAD SEED DATA CSVs ────────────────────────────────────────────────
Write-Host "[4/6] Uploading seed data files..." -ForegroundColor Cyan

$seedFiles = @(
    "KPI_Registry_24MAY.csv",
    "Deliverable_Templates_24MAY.csv",
    "Client_Environment_Templates_24MAY.csv"
)

foreach ($file in $seedFiles) {
    $fullPath = Join-Path $SeedDataPath $file
    if (Test-Path $fullPath) {
        Add-PnPFile -Path $fullPath -Folder "SeedData" -ErrorAction SilentlyContinue | Out-Null
        Write-Host "      Uploaded: $file" -ForegroundColor Green
    } else {
        Write-Host "      Not found (skipped): $file" -ForegroundColor Yellow
    }
}

# ─── 5. SOLUTION REGISTRY LIST ───────────────────────────────────────────────
Write-Host "[5/6] Provisioning Solution Registry list..." -ForegroundColor Cyan

$listName = "Solution Registry"
$list = Get-PnPList -Identity $listName -ErrorAction SilentlyContinue

if ($null -eq $list) {
    New-PnPList -Title $listName -Template GenericList -OnQuickLaunch | Out-Null
    Write-Host "      Created list: $listName" -ForegroundColor Green
} else {
    Write-Host "      List exists:  $listName" -ForegroundColor DarkGray
}

# Helper: add field only if it doesn't exist
function Ensure-Field {
    param(
        [string]$List,
        [string]$InternalName,
        [string]$DisplayName,
        [string]$Type,          # Text, Note, DateTime, Boolean, URL, Choice, User
        [string[]]$Choices,     # for Choice fields
        [string]$FieldXml       # raw CAML override (optional)
    )

    $existing = Get-PnPField -List $List -Identity $InternalName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "      Field exists:  $DisplayName" -ForegroundColor DarkGray
        return
    }

    switch ($Type) {
        "Choice" {
            $choiceXml = ($Choices | ForEach-Object { "<CHOICE>$_</CHOICE>" }) -join ""
            $xml = "<Field Type='Choice' Name='$InternalName' DisplayName='$DisplayName' Format='Dropdown'>" +
                   "<CHOICES>$choiceXml</CHOICES></Field>"
            Add-PnPFieldFromXml -List $List -FieldXml $xml | Out-Null
        }
        "Note" {
            Add-PnPField -List $List -InternalName $InternalName -DisplayName $DisplayName `
                         -Type Note -AddToDefaultView | Out-Null
        }
        "Boolean" {
            $xml = "<Field Type='Boolean' Name='$InternalName' DisplayName='$DisplayName'>" +
                   "<Default>0</Default></Field>"
            Add-PnPFieldFromXml -List $List -FieldXml $xml | Out-Null
        }
        "URL" {
            $xml = "<Field Type='URL' Name='$InternalName' DisplayName='$DisplayName' Format='Hyperlink'/>"
            Add-PnPFieldFromXml -List $List -FieldXml $xml | Out-Null
        }
        "User" {
            Add-PnPField -List $List -InternalName $InternalName -DisplayName $DisplayName `
                         -Type User | Out-Null
        }
        default {
            Add-PnPField -List $List -InternalName $InternalName -DisplayName $DisplayName `
                         -Type $Type | Out-Null
        }
    }
    Write-Host "      Created field: $DisplayName" -ForegroundColor Green
}

Ensure-Field -List $listName -InternalName "SolutionName"  -DisplayName "Solution Name"   -Type "Text"
Ensure-Field -List $listName -InternalName "Version"       -DisplayName "Version"          -Type "Text"
Ensure-Field -List $listName -InternalName "Status"        -DisplayName "Status"           -Type "Choice" `
             -Choices @("Draft","Approved","Deprecated")
Ensure-Field -List $listName -InternalName "IsLatest"      -DisplayName "Is Latest"        -Type "Boolean"
Ensure-Field -List $listName -InternalName "PackageLink"   -DisplayName "Package Link"     -Type "URL"
Ensure-Field -List $listName -InternalName "ReleaseDate"   -DisplayName "Release Date"     -Type "DateTime"
Ensure-Field -List $listName -InternalName "ApprovedBy"    -DisplayName "Approved By"      -Type "User"
Ensure-Field -List $listName -InternalName "ChangeSummary" -DisplayName "Change Summary"   -Type "Note"

# ─── 6. GOVERNANCE VALIDATION VIEW ───────────────────────────────────────────
Write-Host "[6/6] Creating governance views..." -ForegroundColor Cyan

# View: Approved Releases (filtered to Status=Approved)
$viewName = "Approved Releases"
$existingView = Get-PnPView -List $listName -Identity $viewName -ErrorAction SilentlyContinue
if ($null -eq $existingView) {
    Add-PnPView -List $listName `
                -Title $viewName `
                -Fields @("SolutionName","Version","IsLatest","PackageLink","ReleaseDate","ApprovedBy","ChangeSummary") `
                -Query "<Where><Eq><FieldRef Name='Status'/><Value Type='Choice'>Approved</Value></Eq></Where>" `
                -SetAsDefault:$false | Out-Null
    Write-Host "      Created view: $viewName" -ForegroundColor Green
} else {
    Write-Host "      View exists:  $viewName" -ForegroundColor DarkGray
}

# View: IsLatest check (Approved + IsLatest=true)
$viewName2 = "Current Releases"
$existingView2 = Get-PnPView -List $listName -Identity $viewName2 -ErrorAction SilentlyContinue
if ($null -eq $existingView2) {
    Add-PnPView -List $listName `
                -Title $viewName2 `
                -Fields @("SolutionName","Version","PackageLink","ReleaseDate","ApprovedBy") `
                -Query "<Where><And><Eq><FieldRef Name='Status'/><Value Type='Choice'>Approved</Value></Eq><Eq><FieldRef Name='IsLatest'/><Value Type='Integer'>1</Value></Eq></And></Where>" `
                -SetAsDefault:$false | Out-Null
    Write-Host "      Created view: $viewName2" -ForegroundColor Green
} else {
    Write-Host "      View exists:  $viewName2" -ForegroundColor DarkGray
}

# ─── SUMMARY ─────────────────────────────────────────────────────────────────
Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║             PMO Platform SharePoint Provisioning Complete        ║
╠══════════════════════════════════════════════════════════════════╣
║  Site              $SiteUrl
║                                                                  ║
║  Libraries         SolutionPackages  (Draft / Approved /         ║
║                                       Deprecated / Archive)      ║
║                    SeedData          (CSV seed files uploaded)   ║
║                    Runbooks          (ReleaseNotes subfolder)    ║
║                                                                  ║
║  List              Solution Registry (8 columns + 2 views)       ║
║                                                                  ║
║  GOVERNANCE REMINDERS                                            ║
║  • Never overwrite an Approved ZIP — publish a new version.      ║
║  • Only Approved releases may be deployed.                       ║
║  • Exactly one IsLatest = true per solution name (Approved).     ║
║  • Every deploy must log version to Solution Registry.           ║
║  • ZIP naming: PMO-Core_v<Major.Minor[.Patch]>_<Status>.zip      ║
╚══════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
