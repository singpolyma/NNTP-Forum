require 'lib/haml_controller'
require 'json'

class ApplicationController < HamlController
	def recognized_types
		['text/html', 'application/xhtml+xml', 'text/plain', 'application/json', 'application/rss+xml']
	end

	def title
		@env['config']['title']
	end

	def stylesheets
		super + [@env['config']['subdirectory'].to_s + '/stylesheets/common.css']
	end

	def render(args={})
		return @error if @error
		args[:content_type] = Rack::Request.new(@env).accept_media_types.select {|type| recognized_types.index(type) }.first
		case args[:content_type]
			when 'text/plain'
				string = @threads.map {|thread|
					body = thread[:body]
					thread.delete(:body)
					thread.map { |k,v|
						"#{k.to_s.gsub(/_/,'-')}: #{v}" if v
					}.compact.join("\n") + "\n\n#{body}"
				}.join("\n\n---\n")
				[200, {'Content-Type' => 'text/plain; charset=utf-8'}, string]
			when 'application/rss+xml'
				[200, {'Content-Type' => 'application/rss+xml; charset=utf-8'}, self.include('views/rss.haml')]
			when 'application/json'
				[200, {'Content-Type' => 'application/json; charset=utf-8'}, @threads.to_json]
			else
				args[:content_type] += '; charset=utf-8' if args[:content_type]
				super(args)
		end
	end
end
