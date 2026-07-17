# FAQ

## Is this project only for AMD 26.6.4?

The repository is a Legion Go 1 workflow project, not an AMD-version-named project. Public Beta v2.1 uses AMD 26.6.4 because that is the target validated for this release. Later public versions may target later AMD packages after separate testing.

## Does compatibility mean any AMD installer works?

No. Public Beta v2.1 supports the validated AMD 26.6.4 reference installer and still proves the exact target payload before installation. A renamed or different AMD release is not accepted as a supported substitute.

## Which starting states are supported?

Public Beta v2.1 supports fresh Lenovo OEM, a validated Public Beta v1.1 / AMD 26.6.2 state, and an existing validated AMD 26.6.4 state for repair or idempotent reruns.

## Why not require one exact Lenovo OEM driver first?

Public Beta v2.1 records and validates the live starting display stack. A healthy compatible prior toolkit state or OEM state can qualify without pretending every machine must begin from one published INF name.

## Why is the Lenovo extension important?

It carries Legion Go-specific compatibility metadata and must be valid, Microsoft hardware-signed, semantically compatible, and attached to the active GPU instance.

## Does the toolkit include AMD files?

No. The user supplies the official AMD installer. The repository contains original scripts and documentation, not redistributed AMD or Lenovo driver payloads.

## Is Microsoft Store required?

No. The validated final arrangement uses native AMD Software and RSXCM without a Store dependency.

## Is Secure Boot permanently disabled?

The workflow requires Secure Boot off while temporary Test Signing is enabled. Script 2 returns Test Signing to off. Secure Boot can be re-enabled manually after completion and Script 4 can be rerun to audit the resulting state.

## Why are there multiple runs of Scripts 1, 2, and 3?

Each crosses a reboot boundary. The next run verifies the live state after Windows starts again rather than trusting stale saved data from the previous boot.

## Should I use Public Beta v2.0?

No. Public Beta v2.1 supersedes v2.0 and is the supported AMD 26.6.4 release.
