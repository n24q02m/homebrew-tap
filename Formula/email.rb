class Email < Formula
  desc "Unified IMAP and SMTP email MCP server and CLI"
  homepage "https://github.com/n24q02m/email"
  url "https://registry.npmjs.org/@n24q02m/email/-/email-1.43.0.tgz"
  sha256 "0f0bf1dde45b2270ee928a1b0e52904a435ec726c5ed1f3263c0de40abce12f1"
  license "Apache-2.0"

  depends_on "node"

  # Every dependency is pinned by integrity hash: a package-lock.json resolved from the
  # published package.json as of its publish time. scripts/bump.py regenerates it.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/email-1.43.0.package-lock.json"
    sha256 "74518d790694a785186621dbb9705ec066c80beeb955b91c7ff12860a8868813"
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
