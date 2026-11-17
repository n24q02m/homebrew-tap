class Notion < Formula
  desc "Workspace and document MCP server and CLI for Notion"
  homepage "https://github.com/n24q02m/notion"
  url "https://registry.npmjs.org/@n24q02m/notion/-/notion-2.44.0.tgz"
  sha256 "854d7acd36125ad7e4057686ad30251ec0b3b14f84bdb006cf7192257cdaab03"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: the release tarball's npm-shrinkwrap.json
  # (the tree its release was tested with) or, for a release without one, a package-lock.json
  # resolved from the published package.json as of its publish time. scripts/bump.py
  # regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/notion-2.44.0.package-lock.json"
    sha256 "7d62a02f341cb50bc1fb12fb0b5c1812f48eb498c784116d41385dbcacec8e9f"
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
