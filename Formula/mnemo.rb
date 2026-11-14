class Mnemo < Formula
  desc "Episodic and semantic memory MCP server and CLI"
  homepage "https://github.com/n24q02m/mnemo"
  url "https://files.pythonhosted.org/packages/95/71/0b6ffcb758e19ee21548ade024aa21883c444fad5c200bad4a8f5bc1a5ea/n24q02m_mnemo-2.22.0-py3-none-any.whl", using: :nounzip
  sha256 "136862dc1f010c46e74c6cd3b7a8461e501a466fad9a71a68257c2cfe488b7fc"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  def install
    # The dependency tree ships prebuilt native extensions whose Mach-O headers have no
    # room for keg relocation, so the keg keeps only the release wheel and uv builds its
    # environment in the uv cache on first run, the same one `uvx --from n24q02m-mnemo` uses.
    libexec.install Dir["*.whl"]
    wheel = libexec.glob("*.whl").first
    python = formula_opt_bin("python@3.13")/"python3.13"
    uv = formula_opt_bin("uv")/"uv"
    env = { UV_PYTHON_DOWNLOADS: "never" }
    # `mnemo` is the memory CLI; `n24q02m-mnemo` starts the MCP server.
    %w[mnemo n24q02m-mnemo].each do |cmd|
      (bin/cmd).write_env_script uv, "tool run --python #{python} --from #{wheel} #{cmd}", env
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/n24q02m-mnemo --version")
  end
end
