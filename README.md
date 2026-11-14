# Homebrew tap — n24q02m

**Homebrew tap for n24q02m's command-line tools, with casks updated by GoReleaser on each upstream release.**

[![CI](https://github.com/n24q02m/homebrew-tap/actions/workflows/ci.yml/badge.svg)](https://github.com/n24q02m/homebrew-tap/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com)
[![Homebrew](https://img.shields.io/badge/Homebrew-tap-FBB040?logo=homebrew&logoColor=white)](https://brew.sh)

```sh
brew install n24q02m/tap/skret
```

Or, to add the tap once then install any future formula from it:

```sh
brew tap n24q02m/tap
brew install skret
```

Cask files in `Casks/` are auto-updated on each upstream release by [goreleaser](https://goreleaser.com/) — do not edit by hand.

Formula files in `Formula/` install the release the registry serves, with every dependency pinned by hash. Node tools install the npm tarball and run `npm ci --omit=dev --ignore-scripts` against `locks/<name>-<version>.package-lock.json`: the tarball's own `npm-shrinkwrap.json`, the tree the release was tested with, or, for a release without one, a lock resolved from the published `package.json` as of its publish time. Python tools install the PyPI wheel into a [uv](https://docs.astral.sh/uv/) virtualenv on Homebrew's `python@3.13` from `locks/<name>-<version>.txt`, the release tag's `uv.lock` exported with hashes (`bump.py` fails unless the export matches the `requirements.lock` asset of a release that publishes one); a dependency that ships only an sdist builds with the hashed backends in `locks/<name>-<version>.build.txt`, and every step runs with `--require-hashes --only-binary :all:`. The virtualenv lives in `$(brew --prefix)/var/<name>/venv`, because prebuilt native extensions in those trees cannot be relocated into a keg. On macOS the Python formulae need Apple silicon, and wet and mnemo need macOS 14 or later, crg macOS 15 or later: the oldest platforms their native wheels support.

The `Bump` workflow (`bump.yml`, run by `workflow_dispatch` with a `package` and an optional `version`) runs `scripts/bump.py <name> --formula Formula/<name>.rb`, which rewrites the version, URL and checksums from the registry and regenerates the lock files, then opens a pull request and merges it once its checks pass. CI checks every formula against the registry and its lock files (`--pinned --check`), warns about any formula behind the registry latest, and installs every formula on macOS.

## Available casks

| Name | Description | Upstream |
|------|-------------|----------|
| skret | Cloud-provider secret manager CLI | [n24q02m/skret](https://github.com/n24q02m/skret) |

## Available formulae

| Name | Description | Upstream |
|------|-------------|----------|
| wet | Streamable HTTP/stdio MCP server and CLI for web extraction and search | [n24q02m/wet](https://github.com/n24q02m/wet) |
| mnemo | Episodic and semantic memory MCP server and CLI | [n24q02m/mnemo](https://github.com/n24q02m/mnemo) |
| crg | Code review and AST symbol graph MCP server and CLI | [n24q02m/crg](https://github.com/n24q02m/crg) |
| telegram | Telegram client and bot MCP server and CLI | [n24q02m/telegram](https://github.com/n24q02m/telegram) |
| email | Unified IMAP and SMTP email MCP server and CLI | [n24q02m/email](https://github.com/n24q02m/email) |
| notion | Notion workspace and document MCP server and CLI | [n24q02m/notion](https://github.com/n24q02m/notion) |
| workspace | Google Workspace MCP server and CLI | [n24q02m/workspace](https://github.com/n24q02m/workspace) |

## License

Apache-2.0.
