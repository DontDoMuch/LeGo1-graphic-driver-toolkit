# Frequently Asked Questions

## Is this an official Lenovo or AMD tool?

No. It is an independent community project.

## Does the repository include AMD's installer or driver binaries?

No. Users must obtain the exact supported installer from an official AMD source. The scripts verify it before use.

## Why is the target so narrow?

Driver installation and OEM integration are hardware- and package-specific. Public Beta v1.0 was validated only on the original Legion Go hardware identity and documented Lenovo baseline.

## Can I use a `-b` installer or another 26.6.2 package?

No. Public Beta v1.0 requires the exact `-c` installer with the documented size and SHA-256.

## Why must Secure Boot be disabled during preparation?

The corrected package uses a locally signed catalog. The validated installation path activates temporary Windows Test Signing while that package is installed and bound.

## Does Test Signing stay enabled?

No. Script 2 disables Test Signing and verifies the corrected stack after a normal-signing reboot.

## Can Secure Boot be re-enabled later?

Yes, after all four scripts pass. Re-enable it manually in UEFI, boot Windows, and rerun Script 4. Test Signing must remain off.

## Why not use DDU?

DDU is not part of the validated workflow and can remove OEM integration state that this project intentionally preserves.

## Why run Scripts 1, 2, and 3 twice?

Each has a reboot boundary that cannot be truthfully verified in the same Windows session. The second run proves the required state after reboot.

## Why does Script 3 ask me to inspect the dashboard and context menu?

Those visible behaviors are part of the validated outcome and cannot be fully inferred from package registration alone.

## Does Script 4 repair problems?

No. Script 4 is a read-only audit. A failed check identifies drift or an incomplete earlier phase.

## Can I edit a script and still use the published hashes?

No. Any edit changes the file hash and creates an unvalidated build.

## Is Public Beta v1.0 guaranteed to work?

No. It completed an end-to-end test on the documented device and baseline, but Windows installations and device states can differ.

## What do donations fund?

They may fund additional handhelds, direct acquisition costs, recovery media,
replacement parts, adapters, and continued validation work.

## Does donating guarantee support for my handheld?

No. A donation allows research and hands-on testing to occur. Support is
announced only after the exact device completes the full validation process.

## Why must the project own or retain a test device?

A one-time installation test is not enough. Future AMD drivers, Windows
updates, regressions, and recovery testing may require repeated access to the
same hardware.
