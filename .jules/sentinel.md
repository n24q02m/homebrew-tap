## 2026-09-20 - [Add Timeout Configurations to GitHub Actions]
 **Vulnerability:** GitHub Action jobs ran without `timeout-minutes`, meaning they could run up to 360 minutes (6 hours) by default, risking resource exhaustion/DoS.
 **Learning:** GitHub Actions defaults can pose security risks if they allow unbounded resource usage when triggered by untrusted sources (e.g. issues or PRs).
 **Prevention:** Always configure an appropriate `timeout-minutes` value for all GitHub Actions jobs, especially those triggered by external events.
