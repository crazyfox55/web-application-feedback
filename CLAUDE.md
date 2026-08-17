# Web Application Feedback ICM Repository

This repository develops and packages the Feedback Workbench umbrella ICM.
The runnable ICM is rooted at `workflow/`; its `CLAUDE.md` governs sessions
created from the package and must not be treated as repository-development
instructions.

## Development Boundaries

- Keep all files required at ICM runtime under `workflow/`.
- Keep completed development and test feedback under `records/`; do not package
  it into new ICM versions.
- Keep human setup documentation and screenshots under `docs/`.
- Preserve the user review gates in the numbered stage contracts.
- Keep `workflow/.how-to-setup/configure-git.sh` aligned with the Eduba platform
  integration contract.
- Keep `icm.yaml` synchronized with the package layout.

## Validation

After changing the umbrella:

1. Verify required paths in `icm.yaml` exist beneath `workflow/`.
2. Build the package with its contents at the archive root:

   ```bash
  git archive --format=zip --output=web-application-feedback.zip HEAD:workflow
   ```

3. Inspect the archive before publishing. It must not contain a `workflow/`
   wrapper, `records/`, `docs/`, or repository-level development files.

`workflow/generate_report.py` is a runtime helper for the platform agent. It
summarizes feedback accumulated inside an umbrella session into `output.html`;
it is not a repository-development validation step.

Do not publish a new live ICM version unless the user explicitly requests it.
