require "../spec_helper"

describe Plombir::Template::Error do
  it "carries file, line, and column" do
    ex = Plombir::Template::Error.new("page.html", 2, 4, "boom")

    ex.file.should eq("page.html")
    ex.line.should eq(2)
    ex.column.should eq(4)
    ex.message.should eq("boom")
  end
end

describe Plombir::Template::Errors do
  it "appends the offending source line" do
    lines = ["<h1>", "{{ title }}", "</h1>"]

    Plombir::Template::Errors.snippet(lines, 2).should eq("\n\n2 │ {{ title }}")
  end

  it "renders a missing line empty instead of crashing" do
    Plombir::Template::Errors.snippet([] of String, 1).should eq("\n\n1 │ ")
  end

  it "fails with body plus snippet" do
    ex = expect_raises(Plombir::Template::Error) do
      Plombir::Template::Errors.fail("page.html", ["abc"], 1, 2, "detail\n")
    end

    ex.file.should eq("page.html")
    ex.line.should eq(1)
    ex.column.should eq(2)
    ex.message.to_s.should eq("detail\n\n\n1 │ abc")
  end

  it "measures edit distance" do
    Plombir::Template::Errors.distance("kitten", "sitting").should eq(3)
    Plombir::Template::Errors.distance("same", "same").should eq(0)
    Plombir::Template::Errors.distance("", "abc").should eq(3)
    Plombir::Template::Errors.distance("abc", "").should eq(3)
  end

  it "finds the closest name" do
    Plombir::Template::Errors.closest("endfor", Plombir::Template::Errors::TAG_NAMES).should eq("end")
    Plombir::Template::Errors.closest("iff", Plombir::Template::Errors::TAG_NAMES).should eq("if")
    Plombir::Template::Errors.closest("elsfi", Plombir::Template::Errors::TAG_NAMES).should eq("elsif")
    Plombir::Template::Errors.closest("incldue", Plombir::Template::Errors::TAG_NAMES).should eq("include")
  end

  it "returns nil when nothing is near enough" do
    Plombir::Template::Errors.closest("xyz", Plombir::Template::Errors::TAG_NAMES).should be_nil
  end

  it "formats the hint line" do
    Plombir::Template::Errors.suggest("endfor", Plombir::Template::Errors::TAG_NAMES).should eq("Did you mean `end`?\n\n")
    Plombir::Template::Errors.suggest("xyz", Plombir::Template::Errors::TAG_NAMES).should be_nil
  end
end
