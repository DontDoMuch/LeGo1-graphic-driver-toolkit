# Public Beta v3.1 validation summary

Field-proven mechanics inherited unchanged from RC2zp:
- dirty Lenovo OEM with two same-ExtensionId amduw23e generations -> PASS;
- multi-member rollback export -> PASS;
- Stage 2 -> PASS;
- Stage 3 -> PASS;
- Stage 4 -> PASS, 0 failed checks;
- exact merged 26.7.1 -> merged publication regression -> PASS.

This public transformation deliberately leaves internal RC2zp class/type
identifiers intact because they are implementation identifiers, not release
branding. Public workflow/result/signer identities use Public Beta v3.1.

Validated hardware scope:
original Legion Go 83E1 internal Radeon 780M.
eGPU remains unvalidated.
