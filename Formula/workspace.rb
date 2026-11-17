class Workspace < Formula
  desc "Google Workspace MCP server and CLI (Docs, Drive, Gmail, Calendar, Sheets)"
  homepage "https://github.com/n24q02m/workspace"
  url "https://registry.npmjs.org/@n24q02m/workspace/-/workspace-0.8.0.tgz"
  sha256 "dd5589c4b09b4353b94f2e8344f31e8f155787bbd334bcaf68b3f474cca47737"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: the release tarball's npm-shrinkwrap.json
  # (the tree its release was tested with) or, for a release without one, a package-lock.json
  # resolved from the published package.json as of its publish time. scripts/bump.py
  # regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/workspace-0.8.0.package-lock.json"
    sha256 "55b1c10076e8024c5f80841fe521cc5536dd31fa2a0444b960114890e06dcb63"
  end

  def install
    resource("lock").stage { buildpath.install Dir["*.json"].first => "package-lock.json" }
    system "npm", "ci", "--omit=dev", "--ignore-scripts", "--no-audit", "--no-fund",
           "--cache=#{HOMEBREW_CACHE}/npm_cache"
    libexec.install Dir["*"]
    (bin/"workspace").write_env_script formula_opt_bin("node")/"node", "#{libexec}/bin/cli.mjs", {}
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/workspace --version")
  end
end
