require "../spec_helper"

describe Plombir::Markdown do
  it "renders headings and paragraphs" do
    Plombir::Markdown.render("# Hello\n\nWorld.\n").should eq("<h1>Hello</h1>\n<p>World.</p>\n")
  end

  it "renders emphasis, code, links, and images" do
    html = Plombir::Markdown.render("**bold** and *italic* with `code`, [link](/a), and ![alt](/i.png).\n")

    html.should contain("<strong>bold</strong>")
    html.should contain("<em>italic</em>")
    html.should contain("<code>code</code>")
    html.should contain("<a href=\"/a\">link</a>")
    html.should contain("<img src=\"/i.png\" alt=\"alt\">")
  end

  it "renders lists, quotes, code blocks, and rules" do
    source = "- a\n- b\n\n1. one\n2. two\n\n> quoted\n\n```crystal\nputs 1\n```\n\n---\n"
    html = Plombir::Markdown.render(source)

    html.should contain("<ul>")
    html.should contain("<ol>")
    html.should contain("<blockquote>")
    html.should contain("<pre><code class=\"language-crystal\">")
    html.should contain("<hr>")
  end

  it "escapes raw HTML instead of injecting it" do
    html = Plombir::Markdown.render("<script>alert(1)</script>\n")

    html.should contain("&lt;script&gt;")
    html.should_not contain("<script>")
  end
end
