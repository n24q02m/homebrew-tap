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

Formula files in `Formula/` install the release the registry serves. Node tools install the npm tarball. Python tools keep the PyPI wheel and run it with [uv](https://docs.astral.sh/uv/) on Homebrew's `python@3.13`; uv builds the dependency environment in its cache on first run, because prebuilt native extensions in those dependency trees cannot be relocated into a keg. `scripts/bump.py <name> --formula Formula/<name>.rb` rewrites the version, URL and checksum from the registry; the upstream release pipeline runs it after each stable release, and CI reports any formula that is behind the registry (`--check`) and installs every formula on macOS.

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
