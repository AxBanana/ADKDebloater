# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

<#
.Synopsis
Output Debloater for the ARK Dev Kit (v2.1) - A_Banana#2877

.Description
Removes any directories found in \ModTools\Output\[ModDirName]\WindowsNoEditor\ and .\ModTools\Output\[ModDirName]\LinuxNoEditor\ which are not contained in [EditorDirectory]\Projects\ShooterGame\Content\Mods\[ModDirName]\

This script may be placed under \ARKEditor (that is, the same directory as ARKDevKit.bat, or /Game/../../../ in UE4 terms), or you can pass the directory with -EditorDirectory.

You may need to check "Change execution policy to allow local PowerShell scripts to run without signing" in Windows settings.

.Parameter ModDirName
The name of the mod directory. Do not pass a full path. (i.e. pass "ExampleMod" rather than "/Content/Mods/ExampleMod")

.Parameter EditorDirectory
The path to the dev kit's directory. Defaults to the script's location if omitted.

.Parameter DryRun
Tells you which directories it would remove and exits. This overrides -Silent.

.Parameter NoConfirmation
Omits the confirmation dialog. Take caution when using this option.

.Parameter Silent
Executes silently. Note that this implies -NoConfirmation.
#>

#Requires -Version 5.1

Param(
    [Parameter(Position=1, Mandatory=$true)][string]$ModDirName,
    [string]$EditorDirectory = "$PSScriptRoot",
    [switch]$DryRun,
    [switch]$NoConfirmation,
    [switch]$Silent
)

# Get path to the sources directory
$ModSourceDir = Join-Path "$EditorDirectory" -ChildPath Projects | Join-Path -ChildPath ShooterGame | Join-Path -ChildPath Content | Join-Path -ChildPath Mods | Join-Path -ChildPath "$ModDirName"

# Get path to the output directory
$ModOutputDir = Join-Path "$EditorDirectory" -ChildPath ModTools | Join-Path -ChildPath Output | Join-Path -ChildPath "$ModDirName"

# Function to only write to output if we are doing a dry run or we're not silent.
function Write-Host-If-Verbose([string]$Text) {
    if ($DryRun -or (-Not $Silent)) {
        Write-Host $Text
    }
}

# Does the mod source directory exist?
if (-Not (Test-Path "$ModSourceDir")) {
    Write-Host-If-Verbose "Missing mod sources directory. Did you misplace this script?"
    exit
}

# Does the output directory exist?
if (-Not (Test-Path "$ModOutputDir")) {
    Write-Host-If-Verbose "Missing mod output directory. Either the script was misplaced or the mod needs to be cooked."
    exit
}

function Get-Bloat-Dirs([string]$PlatformName) {
    $LocalDirsToRemove = @()

    # Get path to the platform directory (WindowsNoEditor or LinuxNoEditor)
    $PlatformDir = Join-Path "$ModOutputDir" "$PlatformName"

    # Does the platform directory exist?
    if (Test-Path "$PlatformDir") {
        
        # Get all child directories
        Get-ChildItem -Path "$PlatformDir" -Directory | ForEach {
            
            # Get the directory name (only the final path segment)
            $DirName = Split-Path $_ -Leaf

            # Get the path to the directory in sources
            $FullPath = Join-Path "$ModSourceDir" "$DirName"
            
            # Check if path exists
            if (-Not (Test-Path "$FullPath")) {
                $LocalDirsToRemove += Join-Path "$PlatformDir" "$_"
            }
        }
    }
    
    return $LocalDirsToRemove
}

$DirsToRemove = @()

# Find directories we want to remove
$DirsToRemove += Get-Bloat-Dirs "WindowsNoEditor"
$DirsToRemove += Get-Bloat-Dirs "LinuxNoEditor"

# Exit if we didn't find any directories
if ($DirsToRemove.Length -eq 0) {
    Write-Host-If-Verbose "No bloat directories detected, exiting."
    exit
}

# Dry run won't actually do it
if ($DryRun) {
    Write-Host "This script would delete the following directories:"
} else {
    Write-Host-If-Verbose "This script will delete the following directories:"
}

Write-Host-If-Verbose ""

# Only write if it's a dry run or verbose
if ($DryRun -or (-Not $Silent)) {
    Write-Host $DirsToRemove -Separator "`r`n"
}

# Exit if we're doing a dry run
if ($DryRun) {
    Write-Host
    Write-Host "Exiting..."
    exit
}

# Confirm removal of directories
if (-Not ($Silent -or $NoConfirmation)) {
    Write-Host
    $Ret = Read-Host "Proceed? (y/n)"
    switch ($Ret) {
        "y" {
            break
        }
        "n" {
            Write-Host "Exiting..."
            exit
        }
        default {
            Write-Host "Invalid input, exiting..."
            exit
        }
    }
}

Write-Host-If-Verbose "Removing directories..."

# Remove directories
$DirsToRemove | ForEach {
    Remove-Item -Recurse "$_"
    Write-Host-If-Verbose "Removed $_"
}

Write-Host-If-Verbose "Directories removed."
Write-Host-If-Verbose "Exiting..."
