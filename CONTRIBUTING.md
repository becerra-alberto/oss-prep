# Contributing to oss-prep

Thank you for your interest in contributing to oss-prep! This document provides guidelines and instructions for contributing.

## Getting Started

### Clone the Repository

```bash
git clone https://github.com/{owner}/oss-prep.git
cd oss-prep
```

### Prerequisites

- **Git** >= 2.20
- **Claude Code** (Anthropic's CLI for Claude) for testing the skill end-to-end

### Project Structure

The project is a Claude Code skill composed of Markdown phase files, shared pattern libraries, and a JSON state schema. There is no build step or compiled output.

- `SKILL.md` -- The thin orchestrator that sequences phases
- `phases/*.md` -- Individual phase definitions (00 through 09)
- `patterns/*.md` -- Shared regex pattern libraries for secrets and PII detection
- `state-schema.json` -- JSON Schema defining the persistent state format

## Development Workflow

### Branch Naming

Use the following prefixes for branch names:

- `feature/` -- New features or phase additions
- `fix/` -- Bug fixes
- `docs/` -- Documentation-only changes
- `refactor/` -- Code restructuring without behavior changes

### Making Changes

1. Create a feature branch from `master`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes, following the conventions below.

3. Test your changes by running `/oss-prep` against a test repository.

4. Commit with descriptive messages:
   ```bash
   git commit -m "feat(phase-N): description of change"
   ```

### Testing

Since oss-prep is a Claude Code skill (Markdown-based), testing is done by invoking the skill against a test git repository:

1. Create or use a test git repository
2. Run `/oss-prep` from the test repo root
3. Verify the relevant phase produces correct findings and behavior

### Linting and Formatting

- Markdown files should follow standard Markdown formatting
- JSON files should be valid and properly indented (2 spaces)
- Shell scripts (if any) should pass `shellcheck`

## Pull Request Process

### Before Submitting

- [ ] All phase files follow the extraction rules (self-contained, declare I/O, reference shared patterns)
- [ ] State schema changes are backward-compatible
- [ ] Phase files include their user gate prompt
- [ ] Pattern libraries use the established regex format
- [ ] You have tested the affected phases against a real repository

### PR Description

Please include:
- **What** the change does
- **Why** the change is needed
- **Which phases** are affected
- **How** you tested the change

### Review Process

1. Submit your pull request against the `master` branch
2. A maintainer will review your changes
3. Address any feedback
4. Once approved, your PR will be merged

## Code Style

### Phase Files

Each phase file must:
- Start with a header block (phase number, name, inputs, outputs)
- Be self-contained with purpose, inputs, execution steps, outputs, and finding format
- Declare I/O explicitly (`Inputs:` and `Outputs:` sections)
- Reference shared patterns instead of inlining regexes
- Include its user gate prompt

### Finding Format

Findings use the prefix pattern `{CATEGORY}{PHASE}-{N}`:
```
### Finding SEC1-1: {title}

- **Severity**: {CRITICAL | HIGH | MEDIUM | LOW}
- **File**: {filepath}
- **Line**: {line number}
- **Detail**: {description}
- **Remediation**: {recommended action}
```

### Commit Messages

Follow conventional commits:
- `feat(phase-N):` -- New feature in a specific phase
- `fix(phase-N):` -- Bug fix in a specific phase
- `docs:` -- Documentation changes
- `refactor:` -- Restructuring without behavior changes
- `chore:` -- Maintenance tasks

## Reporting Issues

### Bug Reports

When filing a bug report, please include:
- Which phase the bug occurs in
- The project profile (language, framework, package manager)
- The expected behavior vs. actual behavior
- Relevant portions of `.oss-prep/state.json`
- The git log of the target repository (if relevant)

### Feature Requests

When requesting a feature:
- Describe the use case
- Explain which phase(s) would be affected
- Provide examples if possible

## Questions?

Open an issue for any questions about contributing. We are happy to help!
