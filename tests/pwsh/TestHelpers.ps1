# TestHelpers.ps1
# Shared setup for all delphi-toolchain-inspect Pester tests.
#
# Dot-source this file at the top of each *.Tests.ps1:
#   . "$PSScriptRoot/TestHelpers.ps1"
#
# Provides (discovery scope -- usable at top level of test files):
#   $ScriptUnderTest    - absolute path to delphi-toolchain-inspect.ps1
#   $FixturesDir        - absolute path to tests/pwsh/fixtures/
#   $MinFixturePath     - absolute path to the minimal valid fixture JSON
#   $ResolveFixturePath - absolute path to the resolve fixture JSON
#
# Provides (run scope -- usable inside BeforeAll / It blocks):
#   Get-ScriptUnderTestPath    - returns absolute path to delphi-toolchain-inspect.ps1
#   Get-MinFixturePath         - returns absolute path to the minimal fixture JSON
#   Get-ResolveFixturePath     - returns absolute path to the resolve fixture JSON
#   Invoke-ToolProcess         - runs delphi-toolchain-inspect.ps1 as a child process and
#                                returns [pscustomobject]@{ ExitCode; StdOut; StdErr }
#
# PESTER 5 SCOPING NOTE:
#   Pester 5 isolates the run phase from the discovery phase entirely.
#   Both variables and functions defined by a top-level dot-source are
#   visible only during discovery and are invisible to BeforeAll and It
#   blocks.  Dot-source this file inside the Describe-level BeforeAll so
#   that its helper functions are available throughout the run phase:
#
#     Describe 'MyFunction' {
#       BeforeAll {
#         . "$PSScriptRoot/TestHelpers.ps1"
#         $script:scriptUnderTest = Get-ScriptUnderTestPath
#         . $script:scriptUnderTest
#       }
#     }
#
#   This file intentionally does NOT dot-source delphi-toolchain-inspect.ps1.
#   That dot-source must happen in the test file's own BeforeAll so that
#   the loaded functions land in the correct scope for It blocks.

$here               = $PSScriptRoot
$FixturesDir        = Join-Path $here 'fixtures'
$MinFixturePath     = Join-Path $FixturesDir 'delphi-compiler-versions.min.json'
$ResolveFixturePath = Join-Path $FixturesDir 'delphi-compiler-versions.resolve.json'

$ScriptUnderTest = Join-Path $here '..' '..' 'source' 'pwsh' 'delphi-toolchain-inspect.ps1'
$ScriptUnderTest = [System.IO.Path]::GetFullPath($ScriptUnderTest)

function Get-ScriptUnderTestPath {
  $path = Join-Path $PSScriptRoot '..' '..' 'source' 'pwsh' 'delphi-toolchain-inspect.ps1'
  return [System.IO.Path]::GetFullPath($path)
}

function Get-MinFixturePath {
  $path = Join-Path $PSScriptRoot 'fixtures' 'delphi-compiler-versions.min.json'
  return [System.IO.Path]::GetFullPath($path)
}

function Get-ResolveFixturePath {
  $path = Join-Path $PSScriptRoot 'fixtures' 'delphi-compiler-versions.resolve.json'
  return [System.IO.Path]::GetFullPath($path)
}

function Invoke-ToolProcess {
  param(
    [Parameter(Mandatory=$true)][string]$ScriptPath,
    [Parameter()][string[]]$Arguments = @()
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = 'pwsh'
  foreach ($a in @('-NoProfile', '-NonInteractive', '-File', $ScriptPath) + $Arguments) {
    [void]$psi.ArgumentList.Add($a)
  }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false

  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  [void]$p.Start()

  # NOTE: sequential ReadToEnd calls carry a known deadlock risk -- if the child
  # fills the stderr pipe buffer before stdout is fully consumed (or vice versa),
  # both processes block waiting for the other side to drain.  This tool produces
  # only a few lines of output so the buffers will not fill in practice, but if
  # output volume grows the reads should be moved to concurrent async jobs or
  # background threads.  See: https://learn.microsoft.com/dotnet/api/system.diagnostics.process.standardoutput#remarks
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  [pscustomobject]@{
    ExitCode = $p.ExitCode
    StdOut   = ($stdout -split '\r?\n' | Where-Object { $_ -ne '' })
    StdErr   = ($stderr -split '\r?\n' | Where-Object { $_ -ne '' })
  }
}
