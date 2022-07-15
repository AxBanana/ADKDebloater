# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

<#
.Synopsis
Output Debloater for the ARK Dev Kit (v3.0) - A_Banana#2877

.Description
Removes any directories found in \ModTools\Output\[ModDirName]\WindowsNoEditor\ and .\ModTools\Output\[ModDirName]\LinuxNoEditor\ which are not contained in [EditorDirectory]\Projects\ShooterGame\Content\Mods\[ModDirName]\

This script may be placed under \ARKEditor (that is, the same directory as ARKDevKit.bat, or /Game/../../../ in UE4 terms), or you can pass the directory with -EditorDirectory.

You may need to check "Change execution policy to allow local PowerShell scripts to run without signing" in Windows settings.

.Parameter ModDirName
The name of the mod directory. Do not pass a full path. (i.e. pass "ExampleMod" rather than "/Content/Mods/ExampleMod")

.Parameter EditorDirectory
The path to the dev kit's directory. Defaults to the script's location if omitted.

.Parameter IgnoreDirsFile
The path to the file containing directories which should be untouched by this script.

.Parameter WhatIf
Tells you which directories it would remove and exits. This overrides -Silent.

.Parameter NoConfirmation
Omits the confirmation dialog. Take caution when using this option.

.Parameter Silent
Executes silently. Note that this implies -NoConfirmation.
#>

#Requires -Version 5.1

Param(
    [Alias("ModName", "Mod", "M")][Parameter(Position=1, Mandatory=$true)][string]$ModDirName,
    [Alias("Directory", "D")][string]$EditorDirectory = $PSScriptRoot,
    [Alias("IgnoreFile", "I")][string]$IgnoreDirsFile,
    [Alias("DryRun", "W")][switch]$WhatIf,
    [Alias("NoConfirm", "NC")][switch]$NoConfirmation,
    [Alias("S")][switch]$Silent
)

# Get path to the sources directory
$ModSourceDir = Join-Path $EditorDirectory -ChildPath Projects | Join-Path -ChildPath ShooterGame | Join-Path -ChildPath Content | Join-Path -ChildPath Mods | Join-Path -ChildPath $ModDirName

# Get path to the output directory
$ModOutputDir = Join-Path $EditorDirectory -ChildPath ModTools | Join-Path -ChildPath Output | Join-Path -ChildPath $ModDirName

# Function to only write to output if we are doing a dry run or we're not silent.
function Write-Host-If-Verbose([string]$Text="", [System.ConsoleColor]$ForegroundColor= [System.Console]::ForegroundColor) {
    if ($WhatIf -or (-not $Silent)) {
        Write-Host $Text -ForegroundColor $ForegroundColor
    }
}

# Does the mod source directory exist?
if (-not (Test-Path $ModSourceDir)) {
    Write-Host-If-Verbose "Missing mod sources directory."
    exit
}

# Does the output directory exist?
if (-not (Test-Path $ModOutputDir)) {
    Write-Host-If-Verbose "Missing mod output directory."
    exit
}

$IgnoreDirs = $null

# Were we given an ignore file?
if (-not [string]::IsNullOrWhiteSpace($IgnoreDirsFile)) {

    # Does the file have a valid section for the mod?
    if ("$(Get-Content $IgnoreDirsFile)" -match "#$ModDirName(.*)#$ModDirName") {

        # Save the ignores
        $IgnoreDirs = $Matches[1].Trim() -split " " -match "\S+"

        # If we're outputting stuff
        if ($WhatIf -or (-not $Silent)) {
            if ($IgnoreDirs.Length -gt 0) {
                $ForEachArgs = @{
                    Process = { Write-Host $_ -ForegroundColor White }
                    Begin = { Write-Host "`r`nThe following directories to ignore were found in file $IgnoreDirsFile`:`r`n" -ForegroundColor Blue }
                    End = { Write-Host }
                }
                $IgnoreDirs | ForEach @ForEachArgs
            } else {
                Write-Host "No directories to ignore were found in file $IgnoreDirsFile."
            }
            
        }
    }
}

function Get-Removable-Dirs([string]$Directory, [string]$OutputDirectory) {

    foreach ($IgnoreDir in $IgnoreDirs) {
        if ([string]::Equals((Join-Path $OutputDirectory $IgnoreDir).TrimEnd("\"), $Directory.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }
    
    $RemovableDirs = @()

    # Get path of Directory relative to OutputDirectory
    $RelativeDirectoryPath = $Directory.Substring($Directory.IndexOf($OutputDirectory) + $OutputDirectory.Length)
    
    # Get the corresponding sources directory
    $SourceDirectory = Join-Path $ModSourceDir $RelativeDirectoryPath

    Write-Host-If-Verbose "Searching for bloat directories in: $Directory" -ForegroundColor Yellow

    # Get subdirectories
    Get-ChildItem -Path $Directory -Directory | ForEach {
        
        $IndividualDir = $_
        
        $DirName = $IndividualDir.BaseName

        # Get this directory's corresponding directory in sources
        $DirSource = Join-Path $SourceDirectory $DirName

        # Does it exist?
        if (-not (Test-Path $DirSource)) {
            $FoundDir = $false

            # Check the ignored directories
            foreach ($IgnoreDir in $IgnoreDirs) {
                # Is this directory a subdirectory?
                if ((Join-Path $OutputDirectory $IgnoreDir).ToLower().StartsWith($IndividualDir.FullName.ToLower())) {
                    $FoundDir = $true
                    break
                }
            }
            # Did we get a match?
            if ($FoundDir) {
                # Check the subdirectories
                $RemovableDirs += Get-Removable-Dirs $IndividualDir.FullName $OutputDirectory
            } else {
                Write-Host-If-Verbose "Found bloat directory: $($IndividualDir.FullName)" -ForegroundColor DarkYellow
                # This directory should be removed since it is not being ignored
                $RemovableDirs += $IndividualDir.FullName
            }
        }
    }
    return $RemovableDirs
}

function Get-Bloat-Dirs([string]$PlatformName) {
    $LocalDirsToRemove = @()

    # Get path to the platform directory (WindowsNoEditor or LinuxNoEditor)
    $PlatformDir = Join-Path $ModOutputDir $PlatformName

    # Get the directories we should remove
    $LocalDirsToRemove += Get-Removable-Dirs $PlatformDir $PlatformDir
    
    return $LocalDirsToRemove
}

$DirsToRemove = @()

# Find directories we want to remove for each platform
$DirsToRemove += Get-Bloat-Dirs "WindowsNoEditor"
$DirsToRemove += Get-Bloat-Dirs "LinuxNoEditor"

Write-Host-If-Verbose

# Exit if we didn't find any directories
if ($DirsToRemove.Length -eq 0) {
    Write-Host-If-Verbose "No bloat directories found, exiting." -ForegroundColor Green
    exit
}

# Dry run won't actually do it
if ($WhatIf) {
    Write-Host "This script would remove the following directories:" -ForegroundColor Blue
} else {
    Write-Host-If-Verbose "This script will remove the following directories:" -ForegroundColor Blue
}

# Only write if it's a dry run or verbose
if ($WhatIf -or (-not $Silent)) {
    Write-Host
    Write-Host $DirsToRemove -Separator "`r`n" -ForegroundColor White
}

# Exit if we're doing a dry run
if ($WhatIf) {
    Write-Host "`r`nExiting..." -ForegroundColor Green
    exit
}

# Confirm removal of directories
if (-not ($Silent -or $NoConfirmation)) {
    $Ret = Read-Host "`r`nProceed? (y/n)"
    switch ($Ret) {
        "y" {
            break
        }
        "n" {
            Write-Host "Exiting..."
            exit
        }
        default {
            Write-Host "Invalid input, exiting..." -ForegroundColor Red
            exit
        }
    }
}

Write-Host-If-Verbose "Removing directories..." -ForegroundColor Green

# Remove directories
$DirsToRemove | ForEach {
    Remove-Item -Recurse $_
    Write-Host-If-Verbose "Removed $_" -ForegroundColor Yellow
}

Write-Host-If-Verbose "Directories removed." -ForegroundColor Green
Write-Host-If-Verbose "Exiting..."
