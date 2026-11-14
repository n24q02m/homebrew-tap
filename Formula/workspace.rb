class Workspace < Formula
  desc "Google Workspace MCP server and CLI (Docs, Drive, Gmail, Calendar, Sheets)"
  homepage "https://github.com/n24q02m/workspace"
  url "https://registry.npmjs.org/@n24q02m/workspace/-/workspace-0.7.0.tgz"
  sha256 "b298886ef8391788567d4545ce2250a2516c457334f658ecaef1e3a13d51fc00"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: a package-lock.json resolved from the
  # published package.json as of its publish time. scripts/bump.py regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/workspace-0.7.0.package-lock.json"
    sha256 "a5df90c43f97a1f70aff95efb16bacb1280ad3e576ce7ccea2aa15989c80d5fb"
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
