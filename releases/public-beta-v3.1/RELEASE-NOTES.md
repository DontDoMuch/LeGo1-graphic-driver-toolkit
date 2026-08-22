# Legion Go AMD 26.7.1 Public Beta v3.1

Bugfix release over Public Beta v3.0. The frozen merged AMD 26.7.1 payload is
unchanged.

## Fixed public-origin failures

- `Multiple standalone Lenovo amduw23e packages are present; origin is ambiguous.`
- `Standalone Lenovo extension DriverVer does not match the active AMD display DriverVersion.`

The first failure was reproduced after DDU -> current Lenovo OEM. Windows
retained two applicable amduw23e generations, both targeting the original
Legion Go and both sharing ExtensionId
`{07A2A561-D001-4503-B239-EF2FE0379EFB}`.

The corrected classifier treats same-ExtensionId generations as one versioned
lineage instead of using raw package count as origin authority.

## Field validation

Dirty Lenovo OEM multi-generation origin:
- Stage 2 PASS
- Stage 3 PASS
- Stage 4 PASS
- 0 final failed checks

Merged -> merged publication regression:
- Stage 2 PASS
- Stage 3 PASS
- Stage 4 PASS
- 0 final failed checks

## Packaging correction

The first unpublished v3.1 package attempt incorrectly performed a broad
RC-to-public text substitution that modified internal type identifiers and was
rejected immediately by the independent parser gate. No launcher or driver
stage started.

This corrected v3.1 package keeps the field-proven internal implementation
identifiers unchanged and applies public branding only to release contracts,
workflow paths, signer identity, evidence names, entrypoint filenames, and
user-facing headers.

The parser gate now also leaves a Downloads transcript on any pre-launch parser
failure.

## Frozen target hashes

INF:
`9C9A8471BC433B93ED7DECD1EBC40A6D9AF619B68C49B3E91421D70D12AB0409`

DAT:
`DD7B29271E068BE01F5FE4F55A136F0049F60822E0D789B9AAF9152E58A9D766`

amdkmdag.sys:
`D8B1ECBB9169259E6D65D38A5CD53D7D6F0606F60471D2BA779B9C7B5F36E4D5`
