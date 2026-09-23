# Contributing

Thanks for helping. This kit is built with its own process, so contributions follow the same rules it installs.

## Ground rules

- **Every rule should come from a real failure.** A process-change issue explains what went wrong without the change. Rules added "just in case" make the process heavier for everyone.
- **Keep the process rules in step.** They appear in three places: `template/docs/DEVELOPMENT-PROCESS.md`, `skills/pairing-with-codex-cli/SKILL.md` and `commands/`. A change in one must be matched in the others.
- **Keep the kit independent of any stack.** Anything specific to a language belongs in a `{{PLACEHOLDER}}` or in `docs/customizing.md`.
- **Never overwrite user files.** The bootstrap only adds files.

## Development

```bash
bash tests/bootstrap.test.sh      # smoke test
shellcheck scripts/*.sh tests/*.sh skills/pairing-with-codex-cli/run-codex.sh
claude plugin validate .          # plugin and marketplace manifests
```

To try your working copy as a plugin, run `/plugin marketplace add /path/to/your/clone`.

## Pull requests

- Branch from `main`. Keep each PR to one change.
- Update `CHANGELOG.md` under **Unreleased**.
- Codex reviews PRs to this repo. Findings are triaged the way the kit describes: blocking findings are fixed, and edge cases become issues.

## Releases

Bump `version` in `.claude-plugin/plugin.json` and in `.claude-plugin/marketplace.json`, move the **Unreleased** entries under the new version, then tag `vX.Y.Z`.
