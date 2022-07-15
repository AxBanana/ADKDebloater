# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

<#
.Synopsis
Output Debloater for the ARK Editor (Version 1.0) - A_Banana#2877

.Description
Removes any directories found in .\ModTools\Output\ModDirName\WindowsNoEditor\ and .\ModTools\Output\ModDirName\LinuxNoEditor\ which are not contained in .\Projects\ShooterGame\Content\Mods\ModDirName\

This script must be placed under \ARKEditor to work. (that is, the same directory as ARKDevKit.bat, or /Game/../../../ in UE4 terms)
The switch -Silent implies -NoConfirmation.

You may need to check "Change execution policy to allow local PowerShell scripts to run without signing" in Windows settings.

.Parameter ModDirName
The name of the mod directory. Do not pass a full path. (i.e. pass "ExampleMod" rather than "/Content/Mods/ExampleMod")
#>


Param(
    [Parameter(Position=1)][string]$ModDirName,
    [switch]$NoConfirmation,
    [switch]$Silent
)



$ModSourceDir = "$PSScriptRoot\Projects\ShooterGame\Content\Mods\$ModDirName"
$ModOutputDir = "$PSScriptRoot\ModTools\Output\$ModDirName"

function Get-BloatDirs([string]$DirName) {
    $LocalDirsToRemove = @()

    $PlatformDir = "$ModOutputDir\$DirName"

    Get-ChildItem -Path $PlatformDir | ForEach {
        
        if ($_.PSIsContainer) {
            $EndDirName = Split-Path $_ -Leaf
            $FullPath = "$ModSourceDir\$EndDirName"
            if (-Not (Test-Path -Path $FullPath)) {
                $LocalDirsToRemove += "$PlatformDir\$_"
            }
        }
    }
    return $LocalDirsToRemove
}

function Write-Host-If-Verbose([string]$Text) {
    if (-Not $Silent) {
        Write-Host $Text
    }
}



if (-Not (Test-Path $ModSourceDir)) {
    Write-Host-If-Verbose "Missing mod sources directory. Did you misplace this script?"
    exit
}

if (-Not (Test-Path $ModOutputDir)) {
    Write-Host-If-Verbose "Missing mod output directory. Either the script was misplaced or the mod needs to be cooked."
    exit
}

$DirsToRemove = @()

$DirsToRemove += Get-BloatDirs "WindowsNoEditor"
$DirsToRemove += Get-BloatDirs "LinuxNoEditor"

if ($DirsToRemove.Length -eq 0) {
    Write-Host-If-Verbose "No bloat directories detected, exiting."
    exit
}

Write-Host-If-Verbose "This script will delete the following directories:"
Write-Host-If-Verbose ""
if (-Not $Silent) {
    Write-Host $DirsToRemove -Separator "`r`n"
}

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

$DirsToRemove | ForEach {
    Remove-Item -Recurse $_
    Write-Host-If-Verbose "Removed $_"
}

Write-Host-If-Verbose "Directories removed."
