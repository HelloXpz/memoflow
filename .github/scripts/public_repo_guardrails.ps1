$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$trackedFiles = @(& git -c core.quotepath=false ls-files)
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to enumerate tracked files with git ls-files.'
}

function Normalize-Path([string]$path) {
  return ($path -replace '\\', '/').Trim()
}

function Is-CodeLikePath([string]$path) {
  $normalized = Normalize-Path $path
  $extension = [System.IO.Path]::GetExtension($normalized).ToLowerInvariant()
  return $extension -in @(
    '.dart', '.yaml', '.yml', '.json', '.plist', '.gradle', '.kts', '.ps1',
    '.sh', '.py', '.swift', '.m', '.mm', '.pbxproj', '.xcconfig', '.properties'
  )
}

function Add-Failure([System.Collections.Generic.List[string]]$target, [string]$message) {
  $target.Add($message) | Out-Null
}

function Add-Warning([System.Collections.Generic.List[string]]$target, [string]$message) {
  $target.Add($message) | Out-Null
}

$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$normalizedTracked = $trackedFiles |
  ForEach-Object { Normalize-Path $_ } |
  Where-Object { $_ -and (Test-Path $_) }

$repoLayoutBlockedPrefixes = @(
  'lib/'
)

$reservedPrivatePathPatterns = @(
  '^overlay/',
  '^private_billing/',
  '^private_entitlements/',
  '^private_ios_runtime/',
  '^private_module_pack/',
  '^memos_flutter_app/lib/private_billing/',
  '^memos_flutter_app/lib/private_entitlements/',
  '^memos_flutter_app/lib/private_ios_runtime/',
  '^memos_flutter_app/lib/private_module_pack/',
  '^memos_flutter_app/lib/billing/',
  '^memos_flutter_app/lib/entitlements/',
  '^memos_flutter_app/lib/storekit/'
)

$allowedPrivateHookFiles = @(
  'memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart',
  'memos_flutter_app/lib/private_hooks/private_extension_bundle.dart',
  'memos_flutter_app/lib/private_hooks/private_extension_bundle_provider.dart'
)

$keywordScanExcludes = @(
  '.github/scripts/public_repo_guardrails.ps1'
)

$weakScanExcludedPrefixes = @(
  'docs/',
  '_tmp/',
  'memos_flutter_app/lib/access_boundary/',
  'memos_flutter_app/lib/i18n/',
  'memos_flutter_app/test/',
  'memos_flutter_app/third_party/'
)

$codeLikeFiles = $normalizedTracked |
  Where-Object {
    $path = $_
    (Is-CodeLikePath $path) -and ($keywordScanExcludes -notcontains $path)
  }

foreach ($path in $normalizedTracked) {
  foreach ($prefix in $repoLayoutBlockedPrefixes) {
    if ($path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      Add-Failure $failures "Blocked repo layout path: $path"
    }
  }

  foreach ($pattern in $reservedPrivatePathPatterns) {
    if ($path -match $pattern) {
      Add-Failure $failures "Reserved private path must not live in public repo: $path"
    }
  }
}

$privateHookFiles = $normalizedTracked |
  Where-Object { $_.StartsWith('memos_flutter_app/lib/private_hooks/', [System.StringComparison]::OrdinalIgnoreCase) }
foreach ($path in $privateHookFiles) {
  if ($allowedPrivateHookFiles -notcontains $path) {
    Add-Failure $failures "Unexpected public private_hooks file: $path"
  }
}

$activeBundlePath = 'memos_flutter_app/lib/private_hooks/active_private_extension_bundle.dart'
if (Test-Path $activeBundlePath) {
  $activeBundleContent = Get-Content $activeBundlePath -Raw
  if ($activeBundleContent -notmatch 'return const <SettingsEntryContribution>\[\];') {
    Add-Failure $failures 'Public active_private_extension_bundle must keep empty settings entries.'
  }
  if ($activeBundleContent -notmatch "AccessDecision\.disabled\('public-default'\)") {
    Add-Failure $failures "Public active_private_extension_bundle must keep diagnostics source 'public-default'."
  }
}

$restrictedShellFiles = @(
  'memos_flutter_app/lib/app.dart',
  'memos_flutter_app/lib/main.dart',
  'memos_flutter_app/lib/features/settings/settings_screen.dart',
  'memos_flutter_app/lib/features/home/main_home_page.dart',
  'memos_flutter_app/lib/features/home/app_drawer.dart',
  'memos_flutter_app/lib/state/settings/preferences_provider.dart',
  'memos_flutter_app/lib/data/models/app_preferences.dart',
  'memos_flutter_app/lib/state/system/session_provider.dart',
  'memos_flutter_app/lib/data/models/account.dart'
)

$strongTerms = @(
  'purchases_flutter',
  'in_app_purchase',
  'store_kit_wrappers',
  'RevenueCat',
  'Adapty',
  'Qonversion',
  'restorePurchase',
  'restorePurchases',
  'manageSubscription',
  'StoreKit',
  'SKProduct',
  'Transaction.currentEntitlements'
)

$weakPatterns = [ordered]@{
  subscription = '(?i)(?<![A-Za-z])subscription(?![A-Za-z])'
  billing     = '(?i)(?<![A-Za-z])billing(?![A-Za-z])'
  receipt     = '(?i)(?<![A-Za-z])receipt(?![A-Za-z])'
  productId   = '(?i)(?<![A-Za-z])productId(?![A-Za-z])'
  premium     = '(?i)(?<![A-Za-z])premium(?![A-Za-z])'
  unlock      = '(?i)(?<![A-Za-z])unlock(?![A-Za-z])'
}

$restrictedCommercialPatterns = [ordered]@{
  subscription     = '(?i)(?<![A-Za-z])subscription(?![A-Za-z])'
  billing          = '(?i)(?<![A-Za-z])billing(?![A-Za-z])'
  receipt          = '(?i)(?<![A-Za-z])receipt(?![A-Za-z])'
  entitlement      = '(?i)(?<![A-Za-z])entitlement(?![A-Za-z])'
  paywall          = '(?i)(?<![A-Za-z])paywall(?![A-Za-z])'
  productId        = '(?i)(?<![A-Za-z])productId(?![A-Za-z])'
  restorePurchase  = '(?i)(?<![A-Za-z])restorePurchase(?![A-Za-z])'
  restorePurchases = '(?i)(?<![A-Za-z])restorePurchases(?![A-Za-z])'
  manageSubscription = '(?i)(?<![A-Za-z])manageSubscription(?![A-Za-z])'
  StoreKit         = '(?i)(?<![A-Za-z])StoreKit(?![A-Za-z])'
  RevenueCat       = '(?i)(?<![A-Za-z])RevenueCat(?![A-Za-z])'
  purchases_flutter = '(?i)(?<![A-Za-z])purchases_flutter(?![A-Za-z])'
  in_app_purchase  = '(?i)(?<![A-Za-z])in_app_purchase(?![A-Za-z])'
}

foreach ($pattern in @('*.p8', '*.mobileprovision', 'AuthKey_*', 'GoogleService-Info.plist', '*.ipa', '*.xcarchive', '*.dSYM.zip')) {
  $matcher = [System.Management.Automation.WildcardPattern]::Get($pattern, 'IgnoreCase')
  $matches = $normalizedTracked | Where-Object { $matcher.IsMatch([System.IO.Path]::GetFileName($_)) }
  foreach ($match in $matches) {
    Add-Failure $failures "Sensitive file blocked: $match"
  }
}

foreach ($term in $strongTerms) {
  foreach ($match in (Select-String -Path $codeLikeFiles -Pattern $term -SimpleMatch)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) strong term '$term'"
  }
}

$weakFiles = $codeLikeFiles | Where-Object {
  $path = $_
  -not ($weakScanExcludedPrefixes | Where-Object { $path.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
}

foreach ($term in $weakPatterns.Keys) {
  $pattern = $weakPatterns[$term]
  foreach ($match in (Select-String -Path $weakFiles -Pattern $pattern)) {
    Add-Warning $warnings "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) weak term '$term'"
  }
}

foreach ($path in $restrictedShellFiles) {
  if (-not (Test-Path $path)) {
    continue
  }

  foreach ($term in $restrictedCommercialPatterns.Keys) {
    $pattern = $restrictedCommercialPatterns[$term]
    foreach ($match in (Select-String -Path $path -Pattern $pattern)) {
      Add-Failure $failures "${path}:$($match.LineNumber) restricted shell term '$term'"
    }
  }

  $lines = Get-Content $path
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    $importPath = $null
    if ($line -match "^import '([^']+)';$") {
      $importPath = $Matches[1]
    } elseif ($line -match '^import "([^"]+)";$') {
      $importPath = $Matches[1]
    }

    if ($null -ne $importPath) {
      if ($importPath -match 'access_boundary/') {
        Add-Failure $failures "${path}:$($index + 1) restricted shell import '$importPath'"
      }
      if ($importPath -match 'private_hooks/' -and $importPath -notmatch 'private_extension_bundle_provider\.dart$') {
        Add-Failure $failures "${path}:$($index + 1) restricted shell import '$importPath'"
      }
      if ($importPath -match '(billing|entitlement|subscription|storekit|store_kit|revenuecat|qonversion|adapty|purchase)') {
        Add-Failure $failures "${path}:$($index + 1) restricted shell import '$importPath'"
      }
    }
  }
}

foreach ($dartFile in ($codeLikeFiles | Where-Object { $_.EndsWith('.dart') })) {
  foreach ($match in (Select-String -Path $dartFile -Pattern 'if\s*\([^\n\r)]*decision\.source\b' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in if"
  }
  foreach ($match in (Select-String -Path $dartFile -Pattern 'switch\s*\([^\n\r)]*decision\.source\b' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in switch"
  }
  foreach ($match in (Select-String -Path $dartFile -Pattern 'decision\.source\b[^\n\r]*\?' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in ternary"
  }
  foreach ($match in (Select-String -Path $dartFile -Pattern '\?[^\n\r:;]*decision\.source\b[^\n\r:;]*:' -AllMatches)) {
    Add-Failure $failures "$($match.Path.Replace($repoRoot + [System.IO.Path]::DirectorySeparatorChar, '').Replace('\\','/')):$($match.LineNumber) decision.source used in ternary"
  }
}

foreach ($warning in $warnings) {
  Write-Host "WARNING: $warning" -ForegroundColor Yellow
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Host "ERROR: $failure" -ForegroundColor Red
  }
  throw "public_repo_guardrails failed with $($failures.Count) blocking issue(s)."
}

Write-Host 'public_repo_guardrails passed.' -ForegroundColor Green
