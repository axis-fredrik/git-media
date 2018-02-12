require 'git-media/transport'

require 'set'

# move large media to remote server via SCP

# git-media.transport scp
# git-media.scpuser someuser
# git-media.scphost remoteserver.com
# git-media.scppath /opt/media

module GitMedia
  module Transport
    class Scp < Base

      def initialize(user, host, path, port)
        @user = user
        @host = host
        @path = path
        unless port === ""
          @sshport = "-p#{port}"
        end
        unless port === ""
          @scpport = "-P#{port}"
        end
      end

      def is_in_store?(obj)
        if `ssh #{@user}@#{@host} #{@sshport} [ -f "#{obj}" ] && echo 1 || echo 0`.chomp == "1"
          STDERR.puts(obj + " exists")
          return true
        else
          STDERR.puts(obj + " doesn't exist")
          return false
        end
      end

      def read?
        return true
      end

      def get_file(hash, to_file)
        from_file = @user+"@"+@host+":"+File.join(@path, hash)
        `scp #{@scpport} "#{from_file}" "#{to_file}"`
        if $? == 0
          STDERR.puts(hash + " downloaded")
          return true
        end
        STDERR.puts(hash + " download failed")
        return false
      end

      def write?
        return true
      end

      def put_file(hash, from_file)
        to_file = @user+"@"+@host+":"+File.join(@path, hash)
        `scp #{@scpport} "#{from_file}" "#{to_file}"`
        if $? == 0
          STDERR.puts(hash + " uploaded")
          return true
        end
        STDERR.puts(hash + " upload failed")
        return false
      end
      
      def get_unpushed(files)
        results =  `ssh #{@user}@#{@host} #{@sshport} ls #{@path} -p | grep -v /`

        keys  = results.split("\n").to_set;

        files.select do |f|
          !keys.include?(f)
        end
      end
      
    end
  end
end
