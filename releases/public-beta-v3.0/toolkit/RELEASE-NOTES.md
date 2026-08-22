# RC2zk

## RC2zk field-hardening delta

- Recognizes the exact field-proven public GitHub 26.6.4 merged Legion Go origin only when both the active INF SHA256 (`73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034`) and driver version (`32.0.31021.5001`) match.
- If that exact prior merged base still has the older Lenovo OEM `amduw23e` extension staged, the extension is exported as rollback material and removed as stale/redundant instead of failing solely because its `DriverVer` differs.
- Unknown AMD origins with a mismatched standalone Lenovo extension remain fail-closed.
- Frozen 26.7.1 INF builder, DAT builder, 190-file manifest, final INF/DAT/kernel identities, MSI products, and final audit contracts are unchanged.


- Fixes the RC2zh field failure where real OEM INF blank lines caused Windows PowerShell 5.1 parameter binding to reject `Get-CatalogFileNameFromInfLines -Lines @(Get-Content ...)`.
- Adds `[AllowEmptyString()]` to the catalog resolver's `string[] Lines` parameter. Blank/comment parsing behavior remains unchanged.
- Adds a functional preflight fixture with blank lines/comments and requires OEM catalog resolution to succeed.
- Frozen driver payload/build contracts remain unchanged.

# Legion Go AMD 26.7.1 v3.0 RC2zk

RC2zk is an **active Driver Store catalog-resolution hotfix** built on RC2zg. The graphics payload remains frozen: RC2zk does not change the merged INF/DAT output semantics, kernel payload, target hardware binding, Lenovo delta content, Stage 3 MSI policy, or rollback model.

## Why RC2zk exists

The clean Lenovo OEM baseline was independently verified before RC2zg:

- active GPU healthy, `Status=OK`, `ProblemCode=0`;
- active Lenovo display version `32.0.23017.1001`;
- active published package `oem51.inf` with exact `u0198040.inf` hash `2F337E2D...ADB22`;
- exact standalone `amduw23e.inf` hash `F878996C...F84C`;
- Test Signing and nointegritychecks OFF.

RC2zg successfully fixed the preceding clean-OEM classifier problem: Stage 2 progressed beyond origin classification. It then failed **before destructive driver replacement** while capturing the active Lenovo catalog identity because `Get-ActiveCatalogIdentity` still hardcoded the final merged-driver catalog filename `u0202643.cat`.

That produced the exact field failure:

`Active display catalog is missing: ...\u0198040.inf_amd64_...\u0202643.cat`

The active repository was Lenovo `u0198040.inf`; therefore asking that OEM repository for the final AMD `u0202643.cat` was invalid. The workflow remained at `ReadyForInstall`, so active display replacement had not been recorded as started.

The same RC2zg run field-proved two earlier hardenings:

- the clean Lenovo OEM origin with absent CN metadata was accepted far enough to reach active-catalog capture;
- a fresh Stage-2 `Failed/1` child contract overrode the observed process-exit-0 transport anomaly and propagated the exact child error;
- failure recovery detected Test Signing ON, configured Test Signing and nointegritychecks OFF, proved both OFF, packaged evidence, and required a no-retry reboot.

## RC2zk changes

### 1. Resolve the active catalog from the active INF

RC2zk no longer assumes every active display package uses `u0202643.cat`.

`Resolve-DriverStoreCatalogForPublishedInf` now:

1. resolves the exact Driver Store row for the live published INF;
2. reads that row's exact `OriginalFileName`;
3. parses applicable `CatalogFile` directives from that INF;
4. prefers `CatalogFile.NTamd64...` on x64, then generic `CatalogFile`, then compatible universal NT decoration;
5. rejects incompatible architecture declarations;
6. rejects missing/ambiguous directives, path traversal/subdirectory values, non-`.cat` names, and physically absent catalog files;
7. returns the exact INF path, repository root, catalog filename, and catalog path.

This means Lenovo `u0198040.inf` is verified against the catalog it actually declares, while the final merged `u0202643.inf` is verified against its own declared catalog.

### 2. Final audit uses the same catalog resolver

Stage 4 now resolves the active catalog from the active final INF instead of constructing its path from a hardcoded filename. Because the final INF identity is already exact-hash pinned, Stage 4 additionally requires the resolved final catalog name to be `u0202643.cat`.

### 3. RC2zg origin and failure hardening retained

RC2zk retains:

- live display DriverVersion ↔ standalone Lenovo extension DriverVer as the legacy OEM coherence authority;
- CN DriverVersion as supplemental only;
- invocation-bound Stage-2 result contracts;
- Failed/1 child-contract normalization over the observed process-exit-0 anomaly;
- automatic Test Signing/nointegritychecks normalization on any managed hard failure;
- no automatic retry after failure recovery.

## Read-only regression fixtures

RC2zk preflight adds in-memory catalog parser fixtures requiring:

- Lenovo-style generic `CatalogFile = u0198040.cat` resolves to `u0198040.cat`;
- `CatalogFile.NTamd64` wins over generic and incompatible ARM64 declarations on x64;
- conflicting equally authoritative x64 catalog declarations fail closed;
- catalog path traversal/subdirectory values fail closed.

No fixture writes files or changes machine state.

## Frozen payload identities

- Final INF SHA-256: `9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409`
- Final DAT SHA-256: `DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766`
- `amdkmdag.sys` SHA-256: `D8B1ECBB9169259E6D65D38A5CD53D7D6F0606F60471D2BA779B9C7B5F36E4D5`
- INF builder SHA-256: `89A0B08BAC44DF011EEB0EE06317E7FFF608DB15B8D17AAA328CB1EB01085117`
- DAT builder SHA-256: `29C6296A6DA3FA56C9AFFF1F82A163D76411B7BB7B97C181E62910B4AA7EEB78`
- Frozen 190-file manifest SHA-256: `C9B6BE9C990030B86BA4A33F0D5736A9E03BF38341B3218BD2653DC3CA246125`

Intentional AMD defaults remain `ColorVibrance_ENABLE_DEF=1` and `ShowRSOverlay=true`.

RC2zk additionally recognizes the exact public 26.6.2 (`32.0.31021.1015`, INF SHA256 `39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E`) and public 26.6.4 (`32.0.31021.5001`, INF SHA256 `73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034`) toolkit architectures with their required standalone Lenovo extension. The extension is exported for rollback and removed only for the 26.7.1 merged transition.
