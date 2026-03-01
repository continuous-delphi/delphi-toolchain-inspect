# delphi-toolchain-inspect

![Status](https://img.shields.io/badge/status-incubator-orange)
![License](https://img.shields.io/github/license/continuous-delphi/delphi-toolchain-inspect)
![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Delphi](https://img.shields.io/badge/delphi-red)
![PowerShell](https://img.shields.io/badge/powershell-7.4%2B-blue)
![Pester](https://img.shields.io/badge/pester-5.7%2B-blue)
![Continuous Delphi](https://img.shields.io/badge/org-continuous--delphi-red)

Deterministic Delphi toolchain discovery and normalization for Delphi systems.

This repository provides two fully independent implementations that share a mission and a
contract:

- `source/delphi` -- Native Delphi Windows console executable
- `source/pwsh` -- Multi-platform PowerShell 7.4+ implementation

Neither implementation is primary. They serve overlapping but distinct audiences and are both
first-class deliverables.


## TLDR;

Curently, these work.  More options being built

```powershell
pwsh delphi-toolchain-inspect.ps1
pwsh delphi-toolchain-inspect.ps1 -Version
pwsh delphi-toolchain-inspect.ps1 -Resolve D7
pwsh delphi-toolchain-inspect.ps1 -Resolve -Name D7
pwsh delphi-toolchain-inspect.ps1 -Resolve "Delphi 11"
pwsh delphi-toolchain-inspect.ps1 -Resolve D7 -Format json
pwsh delphi-toolchain-inspect.ps1 -ListKnown
pwsh delphi-toolchain-inspect.ps1 -ListKnown -Format json
```

## Philosophy

`Continuous Delphi` meets Delphi developers where they are.

Whether you are building manually on a desktop PC, running FinalBuilder scripts on a cloned
server, or ready to adopt (or have already adopted) GitHub Actions, the tools here work at your level today without
requiring you to change everything at once.

The goal is _not_ to replace your workflow - the goal is to _incrementally enhance_ it.

## Two Implementations, One Mission

### Delphi executable (`source/delphi`)

**Audience:**

- Security-conscious shops that will not use cloud CI
- Teams maintaining legacy infrastructure
- Air-gapped environments
- Single-developer systems with tribal build knowledge
- Organizations building their first repeatable build process

**Operational requirements:**

- Windows (Win32/Win64)
- No PowerShell required
- No Git required

The Delphi executable embeds the dataset as a compiled resource and requires no external
files for basic operation. It is a true single-file xcopy deployment.

Dataset resolution priority:

1. `-DataFile <path>` if specified on the command line
2. `delphi-compiler-versions.json` found alongside the executable
3. Embedded resource compiled into the executable

This means the executable works out of the box, but can be updated to a newer dataset
by placing the JSON file alongside it without recompiling. All output indicates which
data source was used via the `datasetSource` field.

For many shops, this will be the only implementation used.

### PowerShell implementation (`source/pwsh`)

**Audience:**

- Teams using modern CI (GitHub Actions, GitLab CI, Jenkins, etc.)
- Shops comfortable with scripting
- Hybrid environments combining scripting and native builds

**Operational requirements:**

- PowerShell 7.4+
- Windows for registry-based detection commands (RAD Studio currently only installs on Windows)

Dataset resolution priority (if `-DataFile` is not specified):

1. `-DataFile <path>` if specified on the command line
2. `delphi-compiler-versions.json` found alongside the script
3. Embedded `here-string` compiled into the script by the generator

**Development and test requirements:**

- PowerShell 7.4+
- Pester 5.7+
- CI pins Pester to a specific patch version for reproducibility

## Shared Contract

- Both implementations provide equivalent behavior and identical exit codes for shared commands
- Human-readable text output may differ between implementations
- Machine-readable JSON output will remain _semantically equivalent_ across both implementations
  regardless of formatting or whitespace.

### Shared commands

| Command           | Description                                      |
|-------------------|--------------------------------------------------|
| `Version`         | Print tool version and dataset metadata          |
| `ListKnown`       | List all known Delphi versions from the dataset  |
| `DetectInstalled` | Detect installed Delphi versions via registry    |
| `Resolve`         | Resolve an alias or VER### to a canonical entry  |

Both implementations use single-dash PascalCase switches (`-Version`, `-ListKnown`).
This is the recognized PowerShell standard and is adopted for both implementations to
ensure identical parameter syntax.

See [docs/commands.md](docs/commands.md) for full command reference including switches,
output formats, and any functionality differences between implementations.

### Exit codes

| Code | Meaning                                                   |
|------|-----------------------------------------------------------|
| `0`  | Success                                                   |
| `1`  | Unexpected error                                          |
| `2`  | Invalid arguments                                         |
| `3`  | Dataset missing or unreadable                             |
| `4`  | No Delphi installations detected (DetectInstalled only)   |

Exit codes will match across implementations for equivalent commands.

**PowerShell implementation note:** the PowerShell binder runs before the
script body, so parameter binding failures (missing mandatory parameter,
conflicting parameter set) also produce exit 1.  They are distinguishable
from script-body errors only by the stderr message.  Exit 2 is reserved for
invalid-argument conditions detected inside the script body.

### Machine output contract

When JSON output is requested (`-Format json`), both implementations emit a stable JSON
envelope.

Property names in `result` match the dataset field names exactly.

Success (`-Version`):

```json
{
  "ok": true,
  "command": "version",
  "tool": {
    "name": "delphi-toolchain-inspect",
    "impl": "pwsh|delphi",
    "version": "X.Y.Z"
  },
  "result": {
    "schemaVersion": "1.0.0",
    "dataVersion": "0.1.0",
    "generatedUtcDate": "YYYY-MM-DD"
  }
}
```

Success (`-Resolve`):

```json
{
  "ok": true,
  "command": "resolve",
  "tool": {
    "name": "delphi-toolchain-inspect",
    "impl": "pwsh|delphi",
    "version": "X.Y.Z"
  },
  "result": {
    "verDefine": "VER150",
    "productName": "Delphi 7",
    "compilerVersion": "15.0",
    "packageVersion": "70",
    "regKeyRelativePath": "\\Software\\Borland\\Delphi\\7.0",
    "aliases": ["VER150", "Delphi7", "D7"]
  }
}
```

All `result` fields are always present in JSON output; optional fields that are
absent in the dataset appear as `null` rather than being omitted.

Error:

```json
{
  "ok": false,
  "command": "version",
  "tool": {
    "name": "delphi-toolchain-inspect",
    "impl": "pwsh|delphi",
    "version": "X.Y.Z"
  },
  "error": {
    "code": 3,
    "message": "Data file not found: ..."
  }
}
```

## Dataset

Both implementations consume the canonical dataset from
[delphi-compiler-versions](https://github.com/continuous-delphi/delphi-compiler-versions).
The JSON dataset is the single source of truth. Version tables should not be duplicated in code.

During development, the dataset is referenced as a Git submodule. Clone with:

```
git clone --recurse-submodules https://github.com/continuous-delphi/delphi-toolchain-inspect
```

The `gen/` folder produces a standalone `pwsh` script with the dataset embedded as a
PowerShell `here-string`. (The Delphi executable references the dataset directly as a project
resource.)

Both standalone artifacts support the same three-tier dataset resolution priority. Placing
a newer `delphi-compiler-versions.json` alongside either artifact will take precedence over
the embedded data without regenerating or recompiling.  


## Maturity

This repository is currently `incubator`. Both implementations are under active development.
It will graduate to `stable` once:

- The shared command contract is considered frozen.
- Both implementations pass the shared contract test suite.
- CI is in place for the PowerShell implementation.
- At least one downstream consumer exists.

Until graduation, breaking changes may occur in both implementations.

## Part of Continuous Delphi

This repository follows the Continuous Delphi organization taxonomy. See
[cd-meta-org](https://github.com/continuous-delphi/cd-meta-org) for navigation and governance.

- `docs/org-taxonomy.md` -- naming and tagging conventions
- `docs/versioning-policy.md` -- release and versioning rules
- `docs/repo-lifecycle.md` -- lifecycle states and graduation criteria
