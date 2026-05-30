# Repository Guidelines

## Project Structure & Module Organization

This repository maintains modular Bash installers for XHTTP + CDN deployment. Core installer modules live in `src/` and are ordered by numeric prefix, for example `01-env.sh` through `12-final-output.sh`. Keep new core steps in that sequence and update `.github/scripts/build-install.sh` when adding or removing modules.

Reusable configuration templates are in `templates/`, including Xray, Nginx, Mihomo, and client config templates. Optional deployment modes live under `extensions/dual-cdn/` and `extensions/dual-ip/`. User-facing documentation is in `docs/`, while generated release artifacts are written to `dist/` and should not be edited by hand.

## Build, Test, and Development Commands

- `bash .github/scripts/build-install.sh` builds `dist/install.sh` and `dist/install-xpadding.sh` from `src/`.
- `bash .github/scripts/build-dual-cdn.sh` builds `dist/add-dual-cdn.sh`.
- `bash .github/scripts/build-dual-ip.sh` builds `dist/add-dual-ip.sh`.
- `bash -n path/to/script.sh` performs Bash syntax validation without executing privileged deployment actions.

Run build commands from the repository root. The release workflow runs the same build scripts and uploads the four generated installers.

## Coding Style & Naming Conventions

Use Bash for installer logic and YAML/JSON-style templates for generated service and client configs. Preserve LF line endings; `.gitattributes` enforces LF for `.sh`, `.md`, `.yml`, `.yaml`, and template files. Follow the existing module naming pattern: two-digit execution order plus a short kebab-case description, such as `09-service-check.sh`.

Prefer clear shell functions, quoted variables, and explicit error handling. Existing build scripts use `set -euo pipefail`; use the same standard for new builder utilities. Keep user prompts and generated output consistent with the current Chinese documentation and messages.

## Testing Guidelines

There is no standalone test suite. Validate changes by rebuilding all installers and running `bash -n` on changed scripts and generated files in `dist/`. For service configuration changes, verify the generated configs with the project's runtime checks, such as `xray -test -config /usr/local/etc/xray/config.json` and `nginx -t`, in an appropriate VPS or container environment.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects and occasional prefixes such as `fix:` and `enh:`. Keep subjects focused, for example `fix: handle missing nginx dependency` or `Update manual deployment section for Ubuntu 24.04`.

Pull requests should describe the deployment mode affected, list validation commands run, and mention documentation updates. Include screenshots or copied terminal output only when they clarify generated client configs, subscriptions, or service-check failures.

## Security & Configuration Tips

Do not commit real UUIDs, private keys, domains, Cloudflare tokens, certificates, or generated client subscription output. Use `YOUR_*` placeholders in examples and templates.
