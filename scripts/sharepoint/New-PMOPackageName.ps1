<#
.SYNOPSIS
    Generates and validates PMO solution ZIP filenames per the naming standard.
.EXAMPLE
    .\New-PMOPackageName.ps1 -SolutionName "PMO-Core" -Major 1 -Minor 2 -Status Approved
    # Output: PMO-Core_v1.2_Approved.zip

    .\New-PMOPackageName.ps1 -SolutionName "PMO-Core" -Major 1 -Minor 2 -Patch 1 -Status Approved
    # Output: PMO-Core_v1.2.1_Approved.zip
#>
param(
    [Parameter(Mandatory)][string]$SolutionName,
    [Parameter(Mandatory)][int]$Major,
    [Parameter(Mandatory)][int]$Minor,
    [int]$Patch = -1,
    [Parameter(Mandatory)][ValidateSet("Draft","Approved","Deprecated")][string]$Status
)

$version = if ($Patch -ge 0) { "v$Major.$Minor.$Patch" } else { "v$Major.$Minor" }
$fileName = "${SolutionName}_${version}_${Status}.zip"

Write-Host $fileName -ForegroundColor Green
return $fileName
