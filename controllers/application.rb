require 'lib/haml_controller'
require 'json'

class ApplicationController < HamlController
	def initialize(env)
		super()
		@env = env
		@req = Rack::Request.new(env)
	end

	def seen
		'seen[]=' + ((@req['seen'] || []) + threads.map {|t| t[:message_id]}).last(100).join('&seen[]=')
	end

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
		args[:content_type] = @req['_accept'] || @req.accept_media_types.select {|type| recognized_types.index(type) }.first
		r = case args[:content_type]
			when 'text/plain'
				if @threads
					string = @threads.map {|thread|
						body = thread[:text]
						thread.delete(:text)
						thread.delete(:body)
						thread.delete(:mime)
						thread.map { |k,v|
							"#{k.to_s.gsub(/_/,'-')}: #{v}" if v
						}.compact.join("\n") + "\n\n#{body}"
					}.join("\n\n---\n")
				else
					string = super(args).last.to_s.gsub(/<[^>]+>/,' ')
				end
				[200, {'Content-Type' => 'text/plain; charset=utf-8'}, string]
			when 'application/rss+xml'
				if @threads
					[200, {'Content-Type' => 'application/rss+xml; charset=utf-8'}, self.include('views/rss.haml')]
				else
					[404, {'Content-Type' => 'application/rss+xml; charset=utf-8'}, '<rss/>']
				end
			when 'application/json'
				if @threads
					@threads.each {|thread| thread.delete(:mime)}
					[200, {'Content-Type' => 'application/json; charset=utf-8'}, @threads.to_json]
				else
					[404, {'Content-Type' => 'application/json; charset=utf-8'}, '{}']
				end
			else
				args[:content_type] += '; charset=utf-8' if args[:content_type]
				super(args)
		end
		# Cache headers. Varnish likes Cache-Control.
		last_modified = ((@threads || []).map {|thread| thread[:date]}.sort.last || Time.now)
		r[1].merge!({'Vary' => 'Accept', 'Cache-Control' => 'public, max-age=240', 'Last-Modified' => (last_modified + 240).rfc2822})
		r
	end
end
