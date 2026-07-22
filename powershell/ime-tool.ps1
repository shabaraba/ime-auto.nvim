# ime-tool.ps1 - Windows IME control for ime-auto.nvim
#
# Mirrors the slot-based approach of the macOS Swift tool (swift/ime-tool.swift):
#   Slot A = Insert mode IME state, Slot B = Normal mode IME state
#
# Known limitation: this Phase 1 implementation switches the active input
# method via Get-WinUserLanguageList / Set-WinUserLanguageList. This changes
# the user's default input method ordering, which most Windows versions apply
# to the focused window almost immediately, but propagation is not guaranteed
# to be instantaneous or reliable in every environment. Full, low-latency
# control requires direct Win32 API integration (e.g. ITfInputProcessorProfiles
# / WM_INPUTLANGCHANGEREQUEST), which is left for a future phase.

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("toggle-from-insert", "toggle-from-normal", "get-current")]
  [string]$Action
)

$ErrorActionPreference = "Stop"

$DataDir = Join-Path $env:LOCALAPPDATA "nvim-data\ime-auto"
$DefaultEnglishTip = "0409:00000409"

function Get-SlotPath {
  param([string]$Slot)

  if ($Slot -notmatch '^[a-zA-Z0-9_-]+$') {
    throw "Invalid slot name: $Slot"
  }
  return Join-Path $DataDir "saved-ime-$Slot.txt"
}

function Initialize-DataDir {
  if (-not (Test-Path -Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
  }

  try {
    $acl = Get-Acl -Path $DataDir
    $acl.SetAccessRuleProtection($true, $false)
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
      $identity, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl -Path $DataDir -AclObject $acl
  } catch {
    # Best-effort hardening only; not fatal if ACLs cannot be applied (e.g. non-NTFS volume)
  }
}

function Get-CurrentInputMethodTip {
  $lang = Get-WinUserLanguageList | Where-Object { $_.InputMethodTips.Count -gt 0 } | Select-Object -First 1
  if ($null -eq $lang) {
    return $null
  }
  return $lang.InputMethodTips[0]
}

function Write-Slot {
  param([string]$Slot, [string]$Value)

  Initialize-DataDir
  $path = Get-SlotPath -Slot $Slot
  Set-Content -Path $path -Value $Value -NoNewline -Encoding utf8

  try {
    $acl = Get-Acl -Path $path
    $acl.SetAccessRuleProtection($true, $false)
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
      $identity, "FullControl", "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl -Path $path -AclObject $acl
  } catch {
    # Best-effort hardening only
  }
}

function Read-Slot {
  param([string]$Slot)

  $path = Get-SlotPath -Slot $Slot
  if (Test-Path -Path $path) {
    return (Get-Content -Path $path -Raw).Trim()
  }
  return $null
}

function Switch-InputMethodTip {
  param([string]$Tip)

  if ([string]::IsNullOrEmpty($Tip)) {
    return $false
  }

  try {
    $languageList = @(Get-WinUserLanguageList)
    $targetLanguage = $languageList | Where-Object { $_.InputMethodTips -contains $Tip } | Select-Object -First 1

    if ($null -eq $targetLanguage) {
      Write-Error "InputMethodTip not registered on this system: $Tip"
      return $false
    }

    $rest = $languageList | Where-Object { $_ -ne $targetLanguage }
    $reordered = @($targetLanguage) + $rest
    Set-WinUserLanguageList -LanguageList $reordered -Force
    return $true
  } catch {
    Write-Error $_.Exception.Message
    return $false
  }
}

switch ($Action) {
  "get-current" {
    $tip = Get-CurrentInputMethodTip
    if ($tip) {
      Write-Output $tip
      exit 0
    }
    exit 1
  }

  "toggle-from-insert" {
    $current = Get-CurrentInputMethodTip
    if ($current) {
      Write-Slot -Slot "a" -Value $current
    }

    $target = Read-Slot -Slot "b"
    if (-not $target) {
      $target = $DefaultEnglishTip
    }

    if (Switch-InputMethodTip -Tip $target) {
      exit 0
    }
    exit 1
  }

  "toggle-from-normal" {
    $current = Get-CurrentInputMethodTip
    if ($current) {
      Write-Slot -Slot "b" -Value $current
    }

    $target = Read-Slot -Slot "a"
    if (-not $target) {
      exit 0
    }

    if (Switch-InputMethodTip -Tip $target) {
      exit 0
    }
    exit 1
  }
}
