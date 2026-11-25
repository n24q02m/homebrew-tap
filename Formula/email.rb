class Email < Formula
  desc "Unified IMAP and SMTP email MCP server and CLI"
  homepage "https://github.com/n24q02m/email"
  url "https://registry.npmjs.org/@n24q02m/email/-/email-1.46.0.tgz"
  sha256 "c5fc12c126ea289cfd3c69cce509b8eaaa9cc8e0857596fcd3b54b8e870ad136"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: the release tarball's npm-shrinkwrap.json
  # (the tree its release was tested with) or, for a release without one, a package-lock.json
  # resolved from the published package.json as of its publish time. scripts/bump.py
  # regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/email-1.46.0.package-lock.json"
    sha256 "e1a0b34dfb8810f750e1a2a9c9539874135a6d57444820ab43c218005c3ed60e"
  end

  def install
    resource("lock").stage { buildpath.install Dir["*.json"].first => "package-lock.json" }
    system "npm", "ci", "--omit=dev", "--ignore-scripts", "--no-audit", "--no-fund",
           "--cache=#{HOMEBREW_CACHE}/npm_cache"
    libexec.install Dir["*"]
    (bin/"email").write_env_script formula_opt_bin("node")/"node", "#{libexec}/bin/cli.mjs", {}
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/email --version")
  end
end
