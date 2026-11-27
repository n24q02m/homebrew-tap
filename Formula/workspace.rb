class Workspace < Formula
  desc "Google Workspace MCP server and CLI (Docs, Drive, Gmail, Calendar, Sheets)"
  homepage "https://github.com/n24q02m/workspace"
  url "https://registry.npmjs.org/@n24q02m/workspace/-/workspace-0.11.0.tgz"
  sha256 "949bf9a7767607dbe223acfcd3bdd74a1b17fb0bc82ab0643ce00d5e0d59a08c"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: the release tarball's npm-shrinkwrap.json
  # (the tree its release was tested with) or, for a release without one, a package-lock.json
  # resolved from the published package.json as of its publish time. scripts/bump.py
  # regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/workspace-0.11.0.package-lock.json"
    sha256 "36a5408eecb94772a0a7fe3bce872f4397592bf8662e1e160b3cac063ad0d39f"
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
