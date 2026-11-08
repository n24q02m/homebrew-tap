class Email < Formula
  desc "Unified IMAP and SMTP email MCP server and CLI"
  homepage "https://github.com/n24q02m/email"
  url "https://github.com/n24q02m/email/archive/refs/tags/v1.42.0.tar.gz"
  sha256 "3e04b9e01fc187f2ed0e6ee9eaa6e4b730264705212f05758d6b78667c56b22a"
  license "Apache-2.0"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    system "#{bin}/email", "--help"
  end
end
