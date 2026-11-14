class Email < Formula
  desc "Unified IMAP and SMTP email MCP server and CLI"
  homepage "https://github.com/n24q02m/email"
  url "https://registry.npmjs.org/@n24q02m/email/-/email-1.43.0.tgz"
  sha256 "0f0bf1dde45b2270ee928a1b0e52904a435ec726c5ed1f3263c0de40abce12f1"
  license "Apache-2.0"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec/"bin/email"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/email --version")
  end
end
