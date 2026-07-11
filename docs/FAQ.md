# FAQ

## Is this project only for AMD 26.6.4?

The repository is a Legion Go 1 workflow project, not an AMD-version-named project. Public Beta v2.0 uses AMD 26.6.4 because that is the target validated for this release. Later public versions may target later AMD packages after separate testing.

## Does compatibility mean any AMD installer works?

No. Public Beta v2.0 accepts legitimate packaging and host-state variations, but it still proves the exact 26.6.4 target payload before installation.

## Why not require one exact Lenovo OEM driver first?

Public Beta v2.0 records and validates the live starting display stack. A healthy compatible prior toolkit state or OEM state can qualify without pretending every machine must begin from one package number.

## Why is the Lenovo extension important?

It carries Legion Go-specific compatibility metadata and must be valid, Microsoft hardware-signed, semantically compatible, and attached to the active GPU instance.

## Does the toolkit include AMD files?

No. The user supplies the official AMD installer. The repository contains original scripts and documentation, not redistributed AMD or Lenovo driver payloads.

## Is Microsoft Store required?

No. The validated final arrangement uses native AMD Software and RSXCM without a Store dependency.

## Is Secure Boot permanently disabled?

The workflow requires Secure Boot off while temporary Test Signing is enabled. Script 2 returns Test Signing to off. Secure Boot can be re-enabled manually after completion and Script 4 can be rerun to audit the resulting state.

## Why are there multiple runs of Scripts 1, 2, and 3?

Each crosses a reboot boundary. The second run verifies the live state after Windows starts again rather than trusting stale saved JSON from the previous boot.
