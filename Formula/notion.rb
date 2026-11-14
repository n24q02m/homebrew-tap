class Notion < Formula
  desc "Workspace and document MCP server and CLI for Notion"
  homepage "https://github.com/n24q02m/notion"
  url "https://registry.npmjs.org/@n24q02m/notion/-/notion-2.43.0.tgz"
  sha256 "dbed8dc399c7af59bda609823786b1db00d71112e77a98c69cc813df2e2d9a19"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: a package-lock.json resolved from the
  # published package.json as of its publish time. scripts/bump.py regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/notion-2.43.0.package-lock.json"
    sha256 "505d34a9e1203756457042db0e0bea72544ac49bb4374fcafc5a1bf2edeb6349"
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
