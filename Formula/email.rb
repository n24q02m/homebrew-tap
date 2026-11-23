class Email < Formula
  desc "Unified IMAP and SMTP email MCP server and CLI"
  homepage "https://github.com/n24q02m/email"
  url "https://registry.npmjs.org/@n24q02m/email/-/email-1.45.1.tgz"
  sha256 "024ae729c70e687cb57f1347c720024b72576702d7b37248da7856732d48cdd6"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: the release tarball's npm-shrinkwrap.json
  # (the tree its release was tested with) or, for a release without one, a package-lock.json
  # resolved from the published package.json as of its publish time. scripts/bump.py
  # regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/email-1.45.1.package-lock.json"
    sha256 "8841ca61a76e6627ba9cce5c694891ea731fb4269570e0ccdd8bafcef9a471aa"
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
