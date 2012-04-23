require 'controllers/application'
require 'lib/nntp'
require 'digest'
require 'nokogiri'
require 'kramdown'
require 'mail'

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
			@mime = Mail::Message.new(@headers)
			@headers[:subject] = @mime[:subject].decoded
			@headers[:from] = @mime[:from].decoded

			@threads = NNTP::get_thread(nntp, @env['router.params'][:message_id], (@req['start'] || @headers[:article_num]).to_i, max, @req['start'] ? 10 : 9, @req['seen'])
			@threads.map! {|thread|
				nntp.body(thread[:message_id])
				raise "Error getting body for #{thread[:message_id]}." unless nntp.gets.split(' ')[0] == '222'
				thread[:body] = nntp.gets_multiline.join("\n").force_encoding('utf-8')
				thread
			}
			@threads.unshift(@headers.merge({:body => @body.force_encoding('utf-8')})) unless @req['start']
			@threads.map! {|thread|
				if (email = thread[:from].to_s.match(/<([^>]+)>/)) && (email = email[1])
					thread[:photo] = 'http://www.gravatar.com/avatar/' + Digest::MD5.hexdigest(email.downcase) + '?r=g&d=identicon&size=64'
				end
				unless thread[:content_type]
					nntp.hdr('content-type', thread[:message_id])
					raise "Error getting content-type for #{thread[:message_id]}." unless nntp.gets.split(' ')[0] == '225'
					thread[:content_type] = nntp.gets_multiline.first.split(' ', 2)[1]
				end

				thread[:mime] = Mail::Message.new(thread)
				thread[:mime].body.split!(thread[:mime].boundary)
				# The mail library can be a bit broken. Get the useful text part
				if thread[:mime].body.parts.length > 1
					thread[:text] = thread[:mime].body.parts.select {|p| p[:content_type] && p.body && p[:content_type].decoded =~ /^text\/plain/i && p.body.decoded != ''}.first.body.decoded
				else
					thread[:text] = thread[:mime].body.decoded
				end
				if thread[:mime].html_part
					thread[:body] = thread[:mime].html_part.decoded
					doc = Nokogiri::HTML(thread[:body])
					doc.search('script,style,head').each {|el| el.remove}
					doc.search('a,link').each {|el| el.remove if el['href'] =~ /^javascript:/i }
					doc.search('img,embed,video,audio').each {|el| el.remove if el['src'] =~ /^javascript:/i }
					doc.search('object').each {|el| el.remove if el['data'] =~ /^javascript:/i }
					doc.search('*').each {|el|
						el.remove_attribute('style')
						el.each {|k,v| el.remove_attribute(k) if k =~ /^on/ }
					}
					thread[:body] = doc.at('body').to_xhtml(:encoding => 'UTF-8').sub(/^<body>/, '').sub(/<\/body>$/, '').force_encoding('UTF-8')
				else
					thread[:body] = thread[:text].gsub(/</,'&lt;')
					thread[:body] = thread[:body].gsub(/^>[ >]*/) {|s| s.gsub(/ /,'') + ' '}
					thread[:body] = thread[:body].gsub(/(^[^>].*\n)>/, "\\1\n\n>")
					thread[:body] = thread[:body].gsub(/^(>+)(.+)\n(?=\1>)/,"\\1\\2\n\\1\n")
					thread[:body] = thread[:body].gsub(/^(>+)>(.+)\n(?=\1[^>])/,"\\1>\\2\n\\1\n")
					thread[:body] = Kramdown::Document.new(thread[:body]).to_html.encode('UTF-8')
				end

				thread[:subject] = thread[:mime][:subject].decoded
				thread[:from] = thread[:mime][:from].decoded
				(thread[:newsgroups] || []).reject! {|n| n == @env['config']['server'].path[1..-1]}
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
