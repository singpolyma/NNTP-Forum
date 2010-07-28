require 'controllers/application'
require 'lib/nntp'
require 'digest'
require 'bluecloth'

class ThreadController < ApplicationController
	def initialize(env)
		super
		@env['router.params'][:message_id] = "<#{@env['router.params'][:message_id]}>" unless @env['router.params'][:message_id][0] == '<'
		SimpleProtocol.new(:uri => env['config']['server'], :default_port => 119) { |nntp|
			nntp.group @env['config']['server'].path[1..-1]
			max = nntp.gets.split(' ')[3].to_i
			nntp.article(@env['router.params'][:message_id])
			raise "Error getting article for #{@env['router.params'][:message_id]}." unless nntp.gets.split(' ')[0] == '220'
			headers, @body = nntp.gets_multiline.join("\n").split("\n\n", 2)
			@headers = NNTP::headers_to_hash(headers.split("\n"))
			@threads = NNTP::get_thread(nntp, @env['router.params'][:message_id], (@req['start'] || @headers[:article_num]).to_i, max, @req['start'] ? 10 : 9, @req['seen'])
			@threads.map! {|thread|
p thread
				nntp.body(thread[:message_id])
				raise "Error getting body for #{thread[:message_id]}." unless nntp.gets.split(' ')[0] == '222'
				thread[:body] = nntp.gets_multiline.join("\n").force_encoding('utf-8')
				thread
			}
			@threads.unshift(@headers.merge({:body => @body.force_encoding('utf-8')})) unless @req['start']
			@threads.map {|thread|
				if (email = thread[:from].to_s.match(/<([^>]+)>/)) && (email = email[1])
					thread[:photo] = 'http://www.gravatar.com/avatar/' + Digest::MD5.hexdigest(email.downcase) + '?r=g&d=identicon&size=64'
				end
				encoding = thread[:body].encoding # Silly hack because BlueCloth forgets the encoding
				thread[:body] = BlueCloth.new(thread[:body].gsub(/</,'&lt;'), :escape_html => true).to_html.force_encoding(encoding)
				thread
			}
		}
	rescue Exception
		@error = [404, {'Content-Type' => 'text/plain'}, "Error getting article for: #{@env['router.params'][:message_id]}"]
	end

	attr_reader :threads

	def title
		@env['config']['title'] + ' - ' + @headers[:subject]
	end

	def template
		open('views/thread.haml').read
	end

	def stylesheets
		super + [@env['config']['subdirectory'].to_s + '/stylesheets/thread.css']
	end
end
