# Plombir::Check validates a site without publishing it (roadmap
# Phase 3, item 4): six sections — content, routes, links, assets,
# SEO-lite, search — each returning structured issues over a temp
# build.
#
# Links, assets, and SEO run against a throwaway build in a temp
# directory, so `check` never touches `dist/` and always inspects
# current sources. External URLs are skipped (no network in `check`).
module Plombir
  module Check
    # How much an issue matters: errors fail the command, warnings
    # only fail it with `--strict`.
    enum Severity
      Error
      Warning
    end

    # One finding: what is wrong, where, and how to fix it.
    struct Issue
      getter severity : Severity
      getter section : String
      getter file : String
      getter line : Int32?
      getter message : String
      getter hint : String

      def initialize(
        @severity : Severity,
        @section : String,
        @file : String,
        @message : String,
        @hint : String = "",
        @line : Int32? = nil,
      )
      end

      def error? : Bool
        @severity == Severity::Error
      end

      # `path/to/file:line` or `path/to/file` for display.
      def location : String
        if line = @line
          "#{@file}:#{line}"
        else
          @file
        end
      end
    end
  end
end
