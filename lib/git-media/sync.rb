# Find 41-byte stub files and expand them from local cache (or remote store if not cached)
# Upload cached objects that are not in the remote store
require 'git-media/status'
require 'shellwords'

module GitMedia
  module Sync

    def self.run!
      @push = GitMedia.get_push_transport
      @pull = GitMedia.get_pull_transport

      self.expand_references
      self.update_index
      self.upload_local_cache
    end

    def self.expand_references
      status = GitMedia::Status.find_references
      strCount = status[:to_expand].length.to_s

      status[:to_expand].each_with_index do |tuple, index|
        tree_file = tuple[0]
        hash = tuple[1].enforce_hash

        return 1 unless cache_obj_path = GitMedia::Helpers.ensure_cached(hash,true)

        STDERR.puts "expanding " + (index+1).to_s + " of " + strCount + " : " + tree_file
        GitMedia::Helpers.expand(tree_file,hash)
      end
    end

    def self.update_index
      refs = GitMedia::Status.find_references

      # Split references up into lists of at most 500
      # because most OSs have limits on the size of the argument list
      # TODO: Could probably use the --stdin flag on git update-index to be
      # able to update it in a single call
      refLists = refs[:expanded].each_slice(500).to_a

      refLists.each {
        |refList|

        `git update-index --assume-unchanged -- #{Shellwords.shelljoin(refList)}`
      }
      
      puts "Updated git index"
    end

    def self.upload_local_cache
      # find files in media buffer and upload them
      all_cache = Dir.chdir(GitMedia.cache_path) { Dir.glob('*') }
      unpushed_files = @push.get_unpushed(all_cache)
      unpushed_files.each_with_index do |hash, index|
        puts "Uploading " + hash[0, 8] + " " + (index+1).to_s + " of " + unpushed_files.length.to_s
        @push.push(hash)
      end
      # TODO: if --clean, remove them
    end

  end
end