require "../spec_helper"

describe Plombir::Utils do
  it "slugifies display text" do
    Plombir::Utils.slugify("Hello, World!").should eq("hello-world")
    Plombir::Utils.slugify("  Spaced   Out  ").should eq("spaced-out")
  end

  it "falls back to page for blank input" do
    Plombir::Utils.slugify("!!!").should eq("page")
    Plombir::Utils.slugify("").should eq("page")
  end
end
