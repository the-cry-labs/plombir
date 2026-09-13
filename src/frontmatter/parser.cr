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
    struct Document
      getter data : Hash(String, YAML::Any)
      getter body : String

      def initialize(@data : Hash(String, YAML::Any), @body : String)
      end

      # Returns the string value for *key*, or `nil` when absent.
      def string?(key : String) : String?
        value = @data[key]?
        value ? value.as_s? : nil
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
      return Document.new({} of String => YAML::Any, source) unless opens?(lines)

      closing = find_closing(lines)
      unless closing
        raise Error.new(file, lines.size, unterminated_message(file, lines.size))
      end

      raw = lines[1...closing].join("\n")
      data = parse_yaml(raw, file, closing)
      Document.new(data, lines[(closing + 1)..].join("\n"))
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
