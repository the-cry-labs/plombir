require "../spec_helper"

describe Plombir::Content::Pagination do
  rows = (1..7).map { |i| {"title" => "Post #{i}", "url" => "/posts/#{i}/", "excerpt" => "E#{i}", "date" => "2026-09-13"} }

  it "counts pages with a page-1 minimum" do
    Plombir::Content::Pagination.total_pages(0, 5).should eq(1)
    Plombir::Content::Pagination.total_pages(5, 5).should eq(1)
    Plombir::Content::Pagination.total_pages(7, 5).should eq(2)
    Plombir::Content::Pagination.total_pages(10, 5).should eq(2)
  end

  it "windows rows per page" do
    Plombir::Content::Pagination.page_items(rows, 1, 5).size.should eq(5)
    Plombir::Content::Pagination.page_items(rows, 2, 5).size.should eq(2)
    Plombir::Content::Pagination.page_items(rows, 3, 5).should be_empty
  end

  it "builds default and custom page urls" do
    Plombir::Content::Pagination.page_url("/", nil, 2).should eq("/page/2/")
    Plombir::Content::Pagination.page_url("/blog/", nil, 3).should eq("/blog/page/3/")
    Plombir::Content::Pagination.page_url("/blog/", "/blog/page:num/", 2).should eq("/blog/page2/")
    Plombir::Content::Pagination.page_url("/blog/", "/blog/page/:num/", 2).should eq("/blog/page/2/")
  end

  it "exposes paginator vars with empty-string neighbours" do
    first = Plombir::Content::Pagination.page_items(rows, 1, 5)
    vars = Plombir::Content::Pagination.vars("posts", 5, 1, 2, 7, first, "/", nil)

    vars["paginator.page"].should eq("1")
    vars["paginator.total_pages"].should eq("2")
    vars["paginator.previous_page"].should eq("")
    vars["paginator.previous_page_path"].should eq("")
    vars["paginator.next_page"].should eq("2")
    vars["paginator.next_page_path"].should eq("/page/2/")
    vars["paginator.items"].as(Array(Hash(String, String))).size.should eq(5)

    second = Plombir::Content::Pagination.page_items(rows, 2, 5)
    back = Plombir::Content::Pagination.vars("posts", 5, 2, 2, 7, second, "/", nil)
    back["paginator.previous_page_path"].should eq("/")
    back["paginator.next_page"].should eq("")
  end
end
