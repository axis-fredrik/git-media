require 'pp'
require 'git-media/helpers'

Encoding.default_external = Encoding::UTF_8

module GitMedia
  module Status

    def self.run!(opts)
      @push = GitMedia.get_push_transport
      r = self.find_references
      self.print_references(r, opts[:short])
      r = self.local_cache_status
      self.print_cache_status(r, opts[:short])
    end

    # find tree entries that are likely media references
    def self.find_references
      references = {:to_expand => [], :expanded => [], :deleted => []}
      files = `git ls-tree -l -r HEAD | tr "\\000" \\\\n`.split("\n")
      files = files.map { |f| s = f.split("\t"); [s[0].split(' ').last, s[1]] }
      files = files.select { |f| f[0] == '41' } # it's the right size
      files.each do |tree_size, fname|
        if File.exists?(fname)
          size = File.size(fname)

          # Windows newlines can offset file size by 1
          if size == tree_size.to_i or size == tree_size.to_i + 1
            # TODO: read in the data and verify that it's a sha + newline
            fname = fname.tr("\\","") #remove backslash
            if hash = File.read(fname).stub2hash
              references[:to_expand] << [fname, hash]
            end
          else
            references[:expanded] << fname
          end
        else
          # file was deleted
          references[:deleted] << fname
        end
      end
      references
    end

    def self.print_references(refs, short=false)

      if refs[:to_expand].size > 0
        puts "== Unexpanded Stubs =="
        if short
          puts "Count: " + refs[:to_expand].size.to_s
        else
          refs[:to_expand].each do |file, hash|
            puts "   " + hash[0, 8] + " " + file
          end
          puts
        end
      end
#      if refs[:expanded].size > 0
#        puts "== Expanded Media =="
#        if short
#          puts "Count: " + refs[:expanded].size.to_s
#        else
#          refs[:expanded].each do |file|
#            size = File.size(file)
#            puts "   " + "(#{self.to_human(size)})".ljust(8) + " #{file}"
#          end
#          puts
#        end
#      end
      if refs[:deleted].size > 0
        puts "== Deleted Media =="
        if short
          puts "Count: " + refs[:deleted].size.to_s
        else
          refs[:deleted].each do |file|
            puts "           " + " #{file}"
          end
          puts
        end
      end
    end

    def self.print_cache_status(refs, short)
      if refs[:unpushed].size > 0
        puts "== Unpushed Objects =="
        if short
          puts "Count: " + refs[:unpushed].size.to_s
        else
          refs[:unpushed].each do |hash|
            cache_file = GitMedia.cache_obj_path(hash)
            size = File.size(cache_file)
            puts "   " + "(#{self.to_human(size)})".ljust(8) + ' ' + hash[0, 8]
          end
          puts
        end
      end
      if refs[:pushed].size > 0
        puts "== Pushed Objects =="
        if short
          puts "Count: " + refs[:pushed].size.to_s
        else
          refs[:pushed].each do |hash|
            cache_file = GitMedia.cache_obj_path(hash)
            size = File.size(cache_file)
            puts "   " + "(#{self.to_human(size)})".ljust(8) + ' ' + hash[0, 8]
          end
          puts
        end
      end
    end

    def self.local_cache_status
      # find files in media buffer and upload them
      references = {:unpushed => [], :pushed => []}
      all_cache = Dir.chdir(GitMedia.cache_path) { Dir.glob('*') }
      all_cache_set = all_cache.to_set
      unpushed_files = @push.list(all_cache_set,all_cache_set) || []
      references[:unpushed] = unpushed_files
      references[:pushed] = all_cache - unpushed_files rescue []
      references
    end


    def self.to_human(size)
      if size < 1024
        return size.to_s + 'b'
      elsif size < 1048576
        return (size / 1024).to_s + 'k'
      else
        return (size / 1048576).to_s + 'm'
      end
    end

  end
end
