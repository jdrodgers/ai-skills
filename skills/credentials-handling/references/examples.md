# Secret accessor examples

Each example reads a secret in this order: environment variable → `config.local.json` in the project root → error. Keep this as the only place in the codebase that touches secrets.

`config.example.json` (committed):
```json
{
  "STRIPE_API_KEY": "<your-stripe-api-key>",
  "DB_PASSWORD": "<your-db-password>"
}
```

## Python

```python
# secrets_config.py
import json
import os
from functools import lru_cache
from pathlib import Path

_LOCAL_FILE = Path(__file__).resolve().parent / "config.local.json"


@lru_cache(maxsize=1)
def _local() -> dict:
    if _LOCAL_FILE.exists():
        return json.loads(_LOCAL_FILE.read_text(encoding="utf-8"))
    return {}


def get_secret(name: str) -> str:
    value = os.environ.get(name) or _local().get(name)
    if not value or value.startswith("<"):
        raise RuntimeError(
            f"Missing secret '{name}'. Set the {name} environment variable "
            f"or add it to {_LOCAL_FILE.name} (see config.example.json)."
        )
    return value
```

## Node.js / TypeScript

```ts
// secrets.ts
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const LOCAL_FILE = join(process.cwd(), "config.local.json");
let cache: Record<string, string> | undefined;

function local(): Record<string, string> {
  if (!cache) {
    cache = existsSync(LOCAL_FILE) ? JSON.parse(readFileSync(LOCAL_FILE, "utf8")) : {};
  }
  return cache!;
}

export function getSecret(name: string): string {
  const value = process.env[name] ?? local()[name];
  if (!value || value.startsWith("<")) {
    throw new Error(`Missing secret '${name}'. Set env var ${name} or add it to config.local.json.`);
  }
  return value;
}
```

## PowerShell

```powershell
# Secrets.ps1  — dot-source it:  . "$PSScriptRoot\Secrets.ps1"
$script:LocalSecretsFile = Join-Path $PSScriptRoot 'config.local.json'
$script:LocalSecrets = $null

function Get-Secret {
    param([Parameter(Mandatory)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not $value) {
        if ($null -eq $script:LocalSecrets) {
            $script:LocalSecrets = if (Test-Path $script:LocalSecretsFile) {
                Get-Content $script:LocalSecretsFile -Raw | ConvertFrom-Json
            } else { [pscustomobject]@{} }
        }
        $value = $script:LocalSecrets.$Name
    }
    if (-not $value -or $value.StartsWith('<')) {
        throw "Missing secret '$Name'. Set env var $Name or add it to config.local.json."
    }
    return $value
}
```

## C# / .NET

.NET has this built in. Use **User Secrets** in development (stored under `%APPDATA%\Microsoft\UserSecrets\`, outside the repo) and environment variables elsewhere:

```bash
dotnet user-secrets init
dotnet user-secrets set "Stripe:ApiKey" "<real value>"
```

```csharp
// Program.cs — CreateBuilder already layers appsettings.json → user secrets (Development) → env vars
var builder = WebApplication.CreateBuilder(args);
string apiKey = builder.Configuration["Stripe:ApiKey"]
    ?? throw new InvalidOperationException("Missing secret Stripe:ApiKey.");
```

For console apps, add `.AddUserSecrets<Program>()` and `.AddEnvironmentVariables()` to the `ConfigurationBuilder`. Keep real values out of `appsettings.json`; put placeholders in `appsettings.example.json` if a template helps.

## Swapping in a key vault later

Change only the accessor body, e.g. try the vault first, then fall back to env var/local file during migration. Call sites (`get_secret("STRIPE_API_KEY")`) stay the same.
