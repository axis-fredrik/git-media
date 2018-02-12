require 'tempfile'
require 'git-media/helpers'

module GitMedia
  module FilterClean

    def self.run!(input=STDIN, output=STDOUT, info_output=true)
      
      input.binmode
      output.binmode

      # Read the first data block
      data = input.read(GM_BUFFER_BYTES)

      if data.stub2hash
        output.write(data) # Pass the stub through
        STDERR.puts("Skipping stub : " + data[0, 8]) if info_output
        return 0
      end

      # determine and initialize our media buffer directory
      media_buffer = GitMedia.get_media_buffer

      start = Time.now

      # Copy the data to a temporary filename within the local cache while hashing it
      tempfile = Tempfile.new('media', media_buffer, :binmode => true)
      hash = GitMedia::Helpers.copy_hashed(tempfile,input,data)

      return 1 unless hash

      # We got here, so we have a complete temp copy and a valid hash; explicitly close the tempfile to prevent 
      # autodeletion, then give it its final name (the hash)
      tempfile.close
      media_file = File.join(media_buffer, hash)
      FileUtils.mv(tempfile.path, media_file)

      elapsed = Time.now - start

      output.puts hash # Substitute stub for data
      STDERR.puts('Caching object : ' + hash + ' : ' + elapsed.to_s) if info_output

      return 0
    end

  end
end