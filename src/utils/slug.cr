# Plombir::Utils.slugify turns display text into URL-safe slugs.
#
# Shared by routing (filename slugs, `:title` permalink tokens) and
# the `| slugify` template filter, so the two can never drift apart.
module Plombir
  module Utils
    # Turns `My Post!` into `my-post`; blank input becomes `page`.
    #
    # ```
    # Plombir::Utils.slugify("Hello, World!") # => "hello-world"
    # ```
    def self.slugify(text : String) : String
      slug = text.downcase.gsub(/[^a-z0-9]+/, "-").strip("-")
      slug.empty? ? "page" : slug
    end
  end
end
