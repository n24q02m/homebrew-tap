## 2024-05-24 - [Unrestricted Default GitHub Token Permissions]
**Vulnerability:** The `.github/workflows/opencode.yml` workflow lacked top-level read-only permissions, which defaults to permissive permissions depending on the repository settings.
**Learning:** Even if jobs define explicit permissions, having a top-level restrictive permissions block prevents accidental leakage of write permissions to newly added jobs or actions that might inadvertently inherit broader default repository token scopes.
**Prevention:** Always declare `permissions: contents: read` (or similar restrictive top-level permissions) at the root of a GitHub Actions workflow file to enforce a secure default for the `GITHUB_TOKEN`.

## 2024-09-23 - [Confused Deputy ChatOps Injection]
**Vulnerability:** The ChatOps trigger `contains(github.event.comment.body, '/oc')` allowed attackers to trick maintainers into quoting malicious payloads or using unrelated phrases like "ocean", inadvertently executing highly privileged commands on their behalf.
**Learning:** Using substring matching (`contains`) for trigger commands is inherently insecure because it processes contextless input, enabling Confused Deputy attacks when maintainers interact with external contributors.
**Prevention:** Always use exact matching or positional anchors (`startsWith`) for ChatOps triggers to ensure commands are executed intentionally and explicitly.

## 2026-09-24 - [AI Code Reviewer Prompt Injection (Unauthorized Approval)]
**Vulnerability:** The AI pull request review bot was authorized to issue an `APPROVE` verdict in its prompt. Since LLMs process user-controlled inputs (like code diffs), a malicious contributor could embed prompt injection instructions to trick the AI into approving a malicious PR, potentially bypassing required branch protections.
**Learning:** LLM agents that interact with untrusted input (such as code from outside contributors) should never be granted the authority to bypass human controls (like approving a pull request) because they remain vulnerable to prompt injection attacks.
**Prevention:** Explicitly restrict the AI agent's allowed actions in the prompt (e.g., only allow `REQUEST_CHANGES` or `COMMENT`), ensuring it cannot issue an `APPROVE` verdict.

## 2026-10-18 - [Supply Chain Attack via Future Version Masquerading]
**Vulnerability:** A workflow was pinned to a malicious commit SHA (`3d3c42e5aac5ba805825da76410c181273ba90b1`) that claimed to be `actions/checkout@v7.0.1` in the comments and tags, despite the official latest release being only `v4`.
**Learning:** Malicious actors can tag arbitrary commits in their forks (or via other mechanisms) to masquerade as non-existent future versions of legitimate actions. Relying purely on the comment next to a SHA without verifying the actual official latest release makes the project vulnerable to supply chain attacks.
**Prevention:** Always verify that a pinned SHA corresponds to a legitimate, current major version from the official repository. Do not trust version comments or tags blindly without checking the official release history.
