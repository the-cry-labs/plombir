require "spec"
require "file_utils"
require "../src/plombir"

# Runs the block with an isolated temporary directory, removed afterwards.
def with_tempdir(& : String ->) : Nil
  dir = File.join(Dir.tempdir, "plombir-spec-#{Random::Secure.hex(8)}")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end
