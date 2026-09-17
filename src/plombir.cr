# Plombir — a modern, extremely fast static site generator.
#
# Philosophy: Write. Build. Ship.
# Licensed under the Mozilla Public License 2.0 (MPL-2.0).
require "yaml"
require "./content/loader"
require "./router/router"
require "./frontmatter/parser"
require "./markdown/renderer"
require "./template/engine_v0"
require "./renderer/page"
require "./scaffold/templates"
require "./scaffold/site"
require "./cli/base"
require "./cli/version"
require "./cli/help"
require "./cli/new"

module Plombir
  VERSION = "0.1.0"
end
