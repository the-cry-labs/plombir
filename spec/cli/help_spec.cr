require "../spec_helper"

describe Plombir::CLI::Help do
  it "lists every top-level command" do
    text = Plombir::CLI::Help.text
    %w[new dev build preview check clean doctor import version help].each do |command|
      text.should contain(command)
    end
  end
end
