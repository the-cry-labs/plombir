# Plombir::Watcher polls the site root for file changes and reports
# them as classified events for the `dev` rebuild loop (roadmap
# Phase 2, item 2).
#
# Polling (mtime + size snapshots) is deliberate: one dependency-free
# file, portable across Linux/macOS/Windows, and a 50ms interval is
# far below the 50–100ms debounce budget, so inotify would buy
# nothing measurable. Revisit only if profiles say otherwise.
module Plombir
  module Watcher
    # Where a changed file belongs in the rebuild graph.
    enum Kind
      Content # content/** — rebuilds the owning page
      Layout  # layouts/** — rebuilds consuming pages
      Asset   # assets/** — passthrough / affected pages
      Config  # plombir.yml — full rebuild
      Public  # public/** — copy through
      Data    # _data/** — full rebuild (every page can read it)
    end

    # How the file changed between two snapshots.
    enum Change
      Created
      Modified
      Deleted
    end

    # One classified change. *path* is relative to the site root
    # (e.g. `"content/posts/hello.md"`).
    struct Event
      getter kind : Kind
      getter path : String
      getter change : Change

      def initialize(@kind : Kind, @path : String, @change : Change)
      end
    end

    # Directories never descended into: build output, watcher state,
    # and hidden trees (`.git` would make every poll expensive).
    SKIP_DIRS = {"dist", ".plombir"}

    # Editor droppings that must never trigger a rebuild.
    IGNORED_SUFFIXES = {"~", ".swp", ".tmp", ".bak"}

    # Classifies a root-relative path, or `nil` when the path is not
    # watched (generated output, dotfiles, stray root files, backups).
    def self.classify(path : String) : Kind?
      return if path.starts_with?(".")
      return if IGNORED_SUFFIXES.any? { |suffix| path.ends_with?(suffix) }

      first, _, _ = path.partition("/")
      case first
      when "content" then Kind::Content
      when "layouts" then Kind::Layout
      when "assets"  then Kind::Asset
      when "public"  then Kind::Public
      when "_data"   then Kind::Data
      else
        Kind::Config if path == "plombir.yml"
      end
    end

    # Identity of one file between polls: mtime plus size, so a
    # same-second rewrite with different content still counts.
    private struct Entry
      getter mtime : Time
      getter size : Int64

      def initialize(@mtime : Time, @size : Int64)
      end
    end

    # Polls a site root. `poll` diffs one scan against the last and
    # is fully deterministic; `watch` loops it with debouncing and
    # yields merged batches until `stop`.
    class Watcher
      getter root : String

      @snapshot : Hash(String, Entry)

      def initialize(@root : String, @interval_ms : Int32 = 50, @debounce_ms : Int32 = 75)
        @snapshot = take_snapshot
        @stopped = Atomic(Bool).new(false)
      end

      # Single scan: classified events since the previous poll (or
      # construction), sorted by path, advancing the snapshot.
      def poll : Array(Event)
        current = take_snapshot
        events = diff(@snapshot, current)
        @snapshot = current
        events
      end

      # Blocks, yielding one merged batch per quiet period. A batch
      # merges the triggering scan with a post-debounce rescan, so a
      # save burst (write + chmod, atomic-save rename pairs) yields a
      # single batch instead of one event per syscall.
      def watch(& : Array(Event) ->) : Nil
        until @stopped.get
          sleep @interval_ms.milliseconds
          first = poll
          next if first.empty? || @stopped.get
          sleep @debounce_ms.milliseconds
          yield self.class.merge(first + poll) unless @stopped.get
        end
      end

      # Asks a running `watch` loop to exit after its current sleep.
      def stop : Nil
        @stopped.set(true)
      end

      # Collapses several events for one path into the last change,
      # except a Created-then-Deleted pair, which nets to nothing and
      # is dropped. Pure function — unit-tested without any sleeps.
      def self.merge(events : Array(Event)) : Array(Event)
        first_change = {} of String => Change
        latest = {} of String => Event
        events.each do |event|
          first_change[event.path] ||= event.change
          latest[event.path] = event
        end
        latest.values.reject do |event|
          event.change == Change::Deleted && first_change[event.path] == Change::Created
        end
      end

      private def diff(old : Hash(String, Entry), current : Hash(String, Entry)) : Array(Event)
        events = [] of Event
        current.each do |path, entry|
          previous = old[path]?
          if previous.nil?
            if kind = Plombir::Watcher.classify(path)
              events << Event.new(kind, path, Change::Created)
            end
          elsif previous.mtime != entry.mtime || previous.size != entry.size
            if kind = Plombir::Watcher.classify(path)
              events << Event.new(kind, path, Change::Modified)
            end
          end
        end
        old.each_key do |path|
          unless current.has_key?(path)
            if kind = Plombir::Watcher.classify(path)
              events << Event.new(kind, path, Change::Deleted)
            end
          end
        end
        events.sort_by(&.path)
      end

      private def take_snapshot : Hash(String, Entry)
        entries = {} of String => Entry
        stack = [""] of String
        until stack.empty?
          relative = stack.pop
          absolute = relative.empty? ? @root : File.join(@root, relative)
          children = begin
            Dir.children(absolute)
          rescue File::NotFoundError | IO::Error
            # Root vanished mid-watch (e.g. tempdir cleanup racing the
            # poll fiber in specs): report empty instead of crashing
            # the fiber with an unhandled exception.
            return {} of String => Entry
          end
          children.each do |child|
            next if child.starts_with?(".")
            child_relative = relative.empty? ? child : File.join(relative, child)
            child_absolute = File.join(absolute, child)
            if Dir.exists?(child_absolute) && !File.symlink?(child_absolute)
              stack << child_relative unless SKIP_DIRS.includes?(child_relative)
            else
              if info = File.info?(child_absolute)
                entries[child_relative] = Entry.new(info.modification_time, info.size)
              end
            end
          end
        end
        entries
      end
    end
  end
end
