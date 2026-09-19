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
end
