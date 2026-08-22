# RC2zk validation delta

## RC2zk upgrade-origin regression

RC2zk adds a fail-closed classifier regression for the exact public 26.6.4 -> 26.7.1 path: the exact 26.6.4 active INF hash + version may carry an older staged Lenovo OEM `amduw23e`, which must classify as stale rollback/cleanup material. The identical extension-version mismatch on an unknown AMD origin remains rejected.


RC2zk is a narrow runtime/preflight hotfix over RC2zh for Windows PowerShell 5.1 empty-string array binding in the generic catalog resolver. No driver payload/build changes.

# RC2zk validation summary

RC2zk preserves the **RC2ze field-proven graphics payload**, RC2zf failure-recovery hardening, and RC2zg clean-OEM origin/Stage-2 result-contract fixes. It corrects one remaining pre-destructive assumption: active catalog verification must use the catalog declared by the active INF, not the final merged driver's catalog filename.

## Field evidence entering RC2zk

RC2zg Stage 2 advanced beyond the clean Lenovo OEM origin classifier, proving that the RC2zg live-driver/Lenovo-extension coherence fix works on the real OEM baseline.

Stage 2 then failed at active catalog capture with:

`Active display catalog is missing: C:\Windows\System32\DriverStore\FileRepository\u0198040.inf_amd64_44e379dcebebe813\u0202643.cat`

The workflow state remained `ReadyForInstall`, so active display replacement had not been recorded as started.

The Stage-2 invocation contract recorded `Status=Failed`, `ExitCode=1`, and the exact catalog error. The launcher observed process exit `0`, correctly treated the fresh Failed/1 child contract as authoritative, and propagated its detail. Failure recovery then proved Test Signing and nointegritychecks OFF and required a no-retry reboot.

## RC2zk required contracts

1. Active catalog identity is resolved from the exact active Driver Store INF.
2. `CatalogFile.NTamd64...` is preferred on x64.
3. Generic `CatalogFile` is accepted when no x64-specific directive supersedes it.
4. Incompatible architecture declarations do not override x64/generic directives.
5. Missing, ambiguous, path-traversing, non-CAT, or physically absent catalog declarations fail closed.
6. Stage 2 never hardcodes `u0202643.cat` while capturing a pre-existing OEM catalog.
7. Stage 4 uses the same INF-declared catalog resolver.
8. Stage 4 still requires the exact final merged driver to resolve to `u0202643.cat`.
9. RC2zg clean-OEM origin classification remains intact.
10. RC2zg Stage-2 failure transport normalization remains failure-only.
11. RC2zf/RC2zg BCD failure recovery remains intact.
12. Frozen INF/DAT builders and 190-file manifest remain byte-identical.

The read-only preflight contains in-memory catalog parser fixtures for Lenovo generic catalog resolution, x64 decorated precedence, ambiguity rejection, and path-traversal rejection.

## Required field gate

Verify archive SHA-256, parse every `.ps1` under Windows PowerShell 5.1 with zero errors, then require RC2zk read-only preflight `PREFLIGHT PASS: True`, failed checks `0`, changes `None`.

After the RC2zg recovery reboot, remove only RC2zg workflow/signer/extraction residue, prove Lenovo OEM and normal BCD remain active, then run RC2zk exactly once.

RC2zk additionally recognizes the exact public 26.6.2 (`32.0.31021.1015`, INF SHA256 `39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E`) and public 26.6.4 (`32.0.31021.5001`, INF SHA256 `73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034`) toolkit architectures with their required standalone Lenovo extension. The extension is exported for rollback and removed only for the 26.7.1 merged transition.
