require "../spec_helper"

describe Plombir::CLI::Version do
  it "prints plombir and the current version" do
    io = IO::Memory.new
    Plombir::CLI::Version.print(io)
    io.to_s.should eq("plombir #{Plombir::VERSION}\n")
  end
end
