require "../spec_helper"

describe Plombir::Utils::Html do
  describe ".minify" do
    it "drops comments, trailing spaces, and blank lines" do
      html = "<p>Hi.</p>   \n\n<!-- a note -->\n<p>Bye.</p>\n"

      Plombir::Utils::Html.minify(html).should eq("<p>Hi.</p>\n<p>Bye.</p>\n")
    end

    it "keeps conditional comments" do
      html = "<!--[if IE 9]>\n<p>Old.</p>\n<![endif]-->\n"

      Plombir::Utils::Html.minify(html).should eq(html)
    end

    it "leaves pre, textarea, script, and style blocks verbatim" do
      html = "<pre>  keep  \n\n  spaces  </pre>\n<p>Hi.</p>   \n"

      Plombir::Utils::Html.minify(html).should eq("<pre>  keep  \n\n  spaces  </pre><p>Hi.</p>\n")
    end

    it "preserves spacing between inline elements" do
      html = "<span>a</span> <span>b</span>\n"

      Plombir::Utils::Html.minify(html).should eq(html)
    end

    it "renders empty input as empty" do
      Plombir::Utils::Html.minify("  \n\n").should eq("")
    end
  end
end
