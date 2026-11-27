class Notion < Formula
  desc "Workspace and document MCP server and CLI for Notion"
  homepage "https://github.com/n24q02m/notion"
  url "https://registry.npmjs.org/@n24q02m/notion/-/notion-2.47.0.tgz"
  sha256 "526f132ecfb37f37654bf43754d39c3a041dba57fa60883fe88fc0d0e782934e"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: the release tarball's npm-shrinkwrap.json
  # (the tree its release was tested with) or, for a release without one, a package-lock.json
  # resolved from the published package.json as of its publish time. scripts/bump.py
  # regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/notion-2.47.0.package-lock.json"
    sha256 "76c605333bff03f903206d077010810753d589b68e6e68869c7a27bdddeb4cd0"
  end

  def install
    resource("lock").stage { buildpath.install Dir["*.json"].first => "package-lock.json" }
    system "npm", "ci", "--omit=dev", "--ignore-scripts", "--no-audit", "--no-fund",
           "--cache=#{HOMEBREW_CACHE}/npm_cache"
    libexec.install Dir["*"]
    (bin/"notion").write_env_script formula_opt_bin("node")/"node", "#{libexec}/bin/cli.mjs", {}
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/notion --version")
  end
end
