# Legion Go 1 Graphics Driver Toolkit — Public Beta v3.0

## Target

Public Beta v3.0 targets **AMD Adrenalin 26.7.1** on the original Lenovo
Legion Go / Legion Go 1.

## What changed

v3.0 is the first release in the project to use a version-aware merged-driver
architecture rather than relying on compatibility metadata workarounds.

Highlights:

- one-command managed launcher;
- exactly two initial Y/N confirmations;
- automatic dependency preparation and reboot/resume flow;
- exact hardware and payload gating;
- explicit Lenovo OEM, Public 26.6.2, and Public 26.6.4 origin handling;
- rollback export of the starting display package and Lenovo extension;
- Lenovo-required graphics semantics merged into the final 26.7.1 INF;
- standalone `amduw23e` removed only after rollback capture when the merged
  26.7.1 target supersedes it;
- active catalog resolved from the actual active INF;
- temporary Test Signing returned to OFF automatically;
- matching AMD Settings and DVR runtime installed and audited;
- invocation-bound stage result contracts;
- bounded stage routing with no automatic failed-stage retry;
- final 65-check persistence audit.

## Final target identity

```text
DriverVersion:
  32.0.31035.1003

Final INF SHA-256:
  9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409

Final amdgcf.dat SHA-256:
  DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766

Final amdkmdag.sys SHA-256:
  D8B1ECBB9169259E6D65D38A5CD53D7D6F0606F60471D2BA779B9C7B5F36E4D5
```

Preserved intended AMD defaults:

```text
ColorVibrance_ENABLE_DEF = 1
ShowRSOverlay            = true
```

No live `ReleaseVersion` spoofing is used.

## Upgrade architecture

Public Beta v3.0 contains exact origin handling for:

- Microsoft Basic Display Adapter on the target Legion Go GPU;
- Lenovo OEM display + Lenovo standalone `amduw23e`;
- exact Public Beta v1.1 / AMD 26.6.2 toolkit state;
- exact Public Beta v2.1 / AMD 26.6.4 toolkit state;
- exact final 26.7.1 state for repair/idempotent reruns.

Exact prior public toolkit display identities:

```text
AMD 26.6.2 / Public Beta v1.1
  DriverVersion: 32.0.31021.1015
  INF SHA-256:   39BD11386ABFE8CB964902B18159801A486AB22FCFA9C622622F4E6B9B9D901E

AMD 26.6.4 / Public Beta v2.1
  DriverVersion: 32.0.31021.5001
  INF SHA-256:   73E8AE95849354D3D52DCB2A583CCB458D33DF22ACCCD0F0C1EE7626FDBD3034
```

Unknown or inconsistent AMD origins fail closed.

## Validation level

- **Public Beta v2.1 / AMD 26.6.4 → Public Beta v3.0 / AMD 26.7.1:**
  physically field-proven end-to-end; **65/65 PASS**.
- **Fresh Lenovo OEM → AMD 26.7.1:** physically field-proven in the immediate
  predecessor using the same frozen target payload and retained OEM path;
  **65/65 PASS**.
- **Public Beta v1.1 / AMD 26.6.2 → AMD 26.7.1:** exact-identity classifier
  and fail-closed regression fixtures pass; this exact RC2zk transition is
  not claimed as a physical field run.

## Provenance

The public executable snapshot remains byte-identical to the final RC2zk
candidate. Internal RC2zk labels are retained only where changing them would
alter a tested executable or validation contract.
