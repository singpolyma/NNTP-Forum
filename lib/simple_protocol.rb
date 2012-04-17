require 'socket'
require 'uri'

class SimpleProtocol
	def initialize(args={})
		server_set args

		@socket = TCPSocket.new(@host, @port)
		gets # Eat banner

		if block_given? # block start/finish wrapper
			yield self
			close
		end
	end

	def close
		@socket.close if @socket
	end

	def send_command(cmd, *args)
		send(format_command(cmd, args))
	end

	def send_multiline(*args)
		args.flatten!
		args.map! {|line| line.gsub(/\r\n/, "\n").gsub(/\r|\n/, "\r\n") } # Normalize newlines
		send(args.join("\r\n") + "\r\n.\r\n") # Append terminator
	end

	def send(data)
		@socket.print(data)
	end

	def gets
		# Read one line and remove the terminator.  Don't choke on any bytes
		# Downstream you probably want to force the encoding over to a real encoding
		@socket.gets.chomp.force_encoding('BINARY')
	end

	def gets_multiline
		buf = ''
		while (line = gets) != '.'
			buf << line << "\n"
		end
		buf.chomp.split("\n")
	end

	def method_missing(method, *args)
		send_command(method.to_s, args)
	end

	protected
	def format_command(cmd, args)
		args.flatten!
		args = args.join(' ')
		raise 'No CR or LF allowed in command string or arguments.' if cmd.index("\r") or cmd.index("\n") or args.index("\r") or args.index("\n")
		"#{cmd} #{args}\r\n"
	end

	def server_set(args)
		if args[:uri] # Allow passing a string or URI object URI for host and port
			args[:uri] = URI::parse(args[:uri]) unless args[:uri].is_a?URI
			args[:host] = args[:uri].host
			args[:port] = args[:uri].port
		end
		args[:port] = args[:default_port] unless args[:port] # Default port is 119
		@host = args[:host]
		@port = args[:port]
	end
end
