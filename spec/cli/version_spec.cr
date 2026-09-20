require "../spec_helper"

describe Plombir::CLI::Version do
  it "prints plombir, the version, and the baked-in commit" do
    io = IO::Memory.new
    Plombir::CLI::Version.print(io)
    io.to_s.should eq("plombir #{Plombir::VERSION} (#{Plombir::COMMIT})\n")
  end

  it "embeds a short SHA, or the unknown fallback outside git" do
    Plombir::COMMIT.should match(/\A([0-9a-f]{4,40}|unknown)\z/)
  end
end
