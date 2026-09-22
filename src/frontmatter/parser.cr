# Plombir::Frontmatter parses the optional YAML metadata block of a page.
#
# A document looks like:
#
# ```markdown
# ---
# title: Hello
# ---
#
# # Hello
# ```
#
# Everything between the first two `---` lines is YAML; the rest is the
# page body. A missing block is fine — the body is the whole source and
# metadata is empty.
module Plombir
  module Frontmatter
    # A parsed document: raw YAML values plus the Markdown body.
    #
    # Derived metadata (`title`, `layout`, `date`, `tags`, `draft?`)
    # applies the roadmap §11.5 defaults — see ADR-002. The source *file*
    # and frontmatter *block_lines* are kept so value errors can report
    # an exact `file:line` like every other Plombir diagnostic.
    struct Document
      getter data : Hash(String, YAML::Any)
      getter body : String
      getter file : String

      def initialize(@data : Hash(String, YAML::Any), @body : String, @file : String = "<input>", @block_lines : Array(String) = [] of String)
      end

      # Returns the string value for *key*, or `nil` when absent.
      def string?(key : String) : String?
        value = @data[key]?
        value ? value.as_s? : nil
      end

      # Returns the page title: explicit `title:`, else the first
      # `# heading`, else *filename_fallback* (usually the slug).
      #
      # ```
      # doc.title("hello-world") # => "Hello, world"
      # ```
      def title(filename_fallback : String) : String
        if raw = @data["title"]?.try(&.as_s?)
          stripped = raw.strip
          return stripped unless stripped.empty?
        end
        first_heading || filename_fallback
      end

      # Returns the layout name, defaulting to `"default"`.
      #
      # ```
      # doc.layout # => "post"
      # ```
      def layout : String
        raw = @data["layout"]?.try(&.as_s?).try(&.strip) || ""
        raw.empty? ? "default" : raw
      end

      # Returns the page date: explicit `date:` (as `YYYY-MM-DD` or
      # RFC3339, quoted or not), else *default* (the caller passes the
      # file mtime — see ADR-002), else `nil`.
      #
      # ```
      # doc.date(File.info(path).modification_time) # => 2026-09-13 00:00:00Z
      # ```
      def date(default : Time? = nil) : Time?
        value = @data["date"]?
        return default if value.nil? || value.raw.nil?
        return value.as_time? if value.as_time?
        if text = value.as_s?
          if parsed = parse_date_string(text.strip)
            return parsed
          end
        end
        raise Error.new(@file, key_line("date"), date_message)
      end

      # Returns tags as a normalized list: `tags: plombir` and the
      # list form both work; items are stripped and empties dropped;
      # a missing key means no tags.
      #
      # ```
      # doc.tags # => ["plombir", "hello"]
      # ```
      def tags : Array(String)
        value = @data["tags"]?
        return [] of String if value.nil? || value.raw.nil?
        if list = value.as_a?
          return list.map { |entry| (entry.as_s? || entry.to_s).strip }.reject(&.empty?)
        end
        if text = value.as_s?
          stripped = text.strip
          return [] of String if stripped.empty?
          return [stripped]
        end
        raise Error.new(@file, key_line("tags"), tags_message)
      end

      # Returns whether the page is a draft (`draft: true`).
      # Underscore paths are handled by `Plombir::Content.discover`.
      #
      # ```
      # doc.draft? # => false
      # ```
      def draft? : Bool
        value = @data["draft"]?
        return false if value.nil? || value.raw.nil?
        unless (bool = value.as_bool?).nil?
          return bool
        end
        if text = value.as_s?
          case text.strip.downcase
          when "true"  then return true
          when "false" then return false
          end
        end
        raise Error.new(@file, key_line("draft"), draft_message)
      end

      # Returns items per page for paginated listings (`paginate: 5`),
      # or `nil` when the page is not paginated (see ADR-007).
      #
      # ```
      # doc.paginate_per_page # => 5
      # ```
      def paginate_per_page : Int32?
        value = @data["paginate"]?
        return nil if value.nil? || value.raw.nil?
        if number = value.as_i?
          return number.to_i32 if number > 0
        end
        if text = value.as_s?
          if number = text.strip.to_i?(whitespace: false)
            return number.to_i32 if number > 0
          end
        end
        raise Error.new(@file, key_line("paginate"), paginate_message)
      end

      # Returns the paginated collection name (`paginate_collection:`),
      # defaulting to `"posts"` (see ADR-007).
      #
      # ```
      # doc.paginate_collection # => "posts"
      # ```
      def paginate_collection : String
        value = @data["paginate_collection"]?
        return "posts" if value.nil? || value.raw.nil?
        if text = value.as_s?
          stripped = text.strip
          return stripped unless stripped.empty?
        end
        raise Error.new(@file, key_line("paginate_collection"), paginate_collection_message)
      end

      # Returns the paginated URL pattern (`paginate_path:` with `:num`),
      # or `nil` when the `<page_url>page/:num/` default applies.
      #
      # ```
      # doc.paginate_path # => "/blog/page:num/"
      # ```
      def paginate_path : String?
        value = @data["paginate_path"]?
        return nil if value.nil? || value.raw.nil?
        if text = value.as_s?
          stripped = text.strip
          return stripped if !stripped.empty? && stripped.includes?(":num")
        end
        raise Error.new(@file, key_line("paginate_path"), paginate_path_message)
      end

      # First `#`-style heading in the body, or `nil` when there is none.
      private def first_heading : String?
        body.each_line do |line|
          if match = line.match(/^\s{0,3}\#{1,6}\s+(.+)$/)
            text = match[1].sub(/\s+#+\s*$/, "").strip
            return text unless text.empty?
          end
        end
        nil
      end

      private def parse_date_string(text : String) : Time?
        Time.parse(text, "%F", Time::Location::UTC)
      rescue Time::Format::Error
        begin
          Time::Format::RFC_3339.parse(text)
        rescue Time::Format::Error
          nil
        end
      end

      # 1-based file line of the `key:` entry, or 1 when unknown.
      # Public for violation reporting (`Schema` points at the key).
      def line_of(key : String) : Int32
        key_line(key)
      end

      private def key_line(key : String) : Int32
        @block_lines.each_with_index do |line, index|
          return index + 2 if line =~ /^\s*#{Regex.escape(key)}\s*:/
        end
        1
      end

      # Raw `key: value` source line for error snippets.
      private def key_source(key : String) : String
        @block_lines.find { |line| line =~ /^\s*#{Regex.escape(key)}\s*:/ }.try(&.strip) || "#{key}: #{@data[key]}"
      end

      # Value errors name the field, the received source line, and
      # what was expected, so `check` and `doctor` can point at the
      # exact key (roadmap §6.2.2 §13-style contract).
      private def field_error(key : String, expected : String, example : String) : String
        String.build do |io|
          io << "✖ Invalid frontmatter\n\n"
          io << @file << ":" << key_line(key) << "\n\n"
          io << "Field: " << key << "\n"
          io << "Received: " << key_source(key) << "\n"
          io << "Expected: " << expected << "\n\n"
          io << "Example:\n" << example << "\n"
        end
      end

      private def date_message : String
        field_error("date", "a date like YYYY-MM-DD or RFC3339", "date: 2026-09-13")
      end

      private def tags_message : String
        field_error("tags", "a single value or a list of values", "tags: plombir")
      end

      private def draft_message : String
        field_error("draft", "true or false", "draft: true")
      end

      private def paginate_message : String
        field_error("paginate", "a page size like 5", "paginate: 5")
      end

      private def paginate_collection_message : String
        field_error("paginate_collection", "a collection name like posts", "paginate_collection: posts")
      end

      private def paginate_path_message : String
        field_error("paginate_path", "a path with :num like /blog/page:num/", "paginate_path: /blog/page:num/")
      end
    end

    # Raised when the frontmatter block exists but cannot be understood.
    class Error < Exception
      getter file : String
      getter line : Int32

      def initialize(@file : String, @line : Int32, message : String)
        super(message)
      end
    end

    # Parses *source* (usually the contents of *file*).
    #
    # ```
    # doc = Plombir::Frontmatter.parse("---\ntitle: Hi\n---\n\nBody\n")
    # doc.data["title"] # => "Hi"
    # doc.body          # => "Body\n"
    # ```
    def self.parse(source : String, file : String = "<input>") : Document
      lines = source.lines
      return Document.new({} of String => YAML::Any, source, file) unless opens?(lines)

      closing = find_closing(lines)
      unless closing
        raise Error.new(file, lines.size, unterminated_message(file, lines.size))
      end

      raw = lines[1...closing].join("\n")
      data = parse_yaml(raw, file, closing)
      Document.new(data, lines[(closing + 1)..].join("\n"), file, lines[1...closing])
    end

    private def self.opens?(lines : Array(String)) : Bool
      !lines.empty? && lines.first.strip == "---"
    end

    # Index of the closing `---` line, or `nil` when there is none.
    private def self.find_closing(lines : Array(String)) : Int32?
      lines.each_with_index.skip(1).find { |line, _| line.strip == "---" }.try &.[1]
    end

    private def self.parse_yaml(raw : String, file : String, closing : Int32) : Hash(String, YAML::Any)
      parsed = YAML.parse(raw)
      return {} of String => YAML::Any if parsed.raw.nil?

      unless mapping = parsed.as_h?
        raise Error.new(file, closing + 1, scalar_message(file, closing + 1))
      end

      mapping.each_with_object({} of String => YAML::Any) do |(key, value), memo|
        memo[key.as_s] = value
      end
    rescue ex : YAML::ParseException
      line = ex.line_number.zero? ? 1 : ex.line_number
      raise Error.new(file, line, invalid_message(file, line, ex.message))
    end

    private def self.unterminated_message(file : String, line : Int32) : String
      String.build do |io|
        io << "✖ Invalid frontmatter\n\n"
        io << file << ":" << line << "\n\n"
        io << "The opening `---` has no closing `---`.\n\n"
        io << "Close the block before the body starts.\n\n"
        io << "Example:\n---\ntitle: Hello\n---\n"
      end
    end

    private def self.scalar_message(file : String, line : Int32) : String
      String.build do |io|
        io << "✖ Invalid frontmatter\n\n"
        io << file << ":" << line << "\n\n"
        io << "Frontmatter must be a mapping of keys to values.\n\n"
        io << "Example:\n---\ntitle: Hello\n---\n"
      end
    end

    private def self.invalid_message(file : String, line : Int32, detail : String?) : String
      String.build do |io|
        io << "✖ Invalid frontmatter\n\n"
        io << file << ":" << line << "\n\n"
        io << detail << "\n\n" if detail
        io << "Expected valid YAML.\n\n"
        io << "Example:\n---\ntitle: Hello\ndate: 2026-09-13\n---\n"
      end
    end
  end
end
