# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Thin orchestrator (`SKILL.md`) with state management, sub-agent dispatch, and phase-gating
- 10 decomposed phase files (`phases/00-recon.md` through `phases/09-final-report.md`)
- Shared regex pattern libraries for secrets (11 categories) and PII (8 categories)
- JSON state schema (`state-schema.json`) for persistent progress tracking
- Resume support via `.oss-prep/state.json`
- Sub-agent failure handling with retry and main-context fallback
- Phase 8 safety features: backup refs, dry-run mode, explicit `flatten` confirmation
