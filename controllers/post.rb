# encoding: utf-8
require 'controllers/application'
require 'lib/nntp'
require 'mail'

class PostController < ApplicationController
	attr_reader :template, :title

	def initialize(env)
		super
	end

	def get
		@title = @env['config']['title'] + ' - '
		if @req.params['message_id']
			@title += 'Reply to message ' + @req.params['message_id']
			@req.params['message_id'] = "<#{@req.params['message_id']}>" unless @req.params['message_id'][0] == '<'
			SimpleProtocol.new(:uri => @env['config']['server'], :default_port => 119) { |nntp|
				nntp.article(@req.params['message_id'])
				raise "Error getting article for #{@req.params['message_id']}." unless nntp.gets.split(' ')[0] == '220'
				@mime = Mail::Message.new(nntp.gets_multiline.join("\r\n"))
			}
			if @mime.body.parts.length > 1
				@text = @mime.body.parts.select {|p| p[:content_type].decoded =~ /^text\/plain/i && p.body.decoded != ''}.first.body.decoded
				@text.force_encoding(@text[:content_type].charset).encode('utf-8')
			else
				@text = @mime.body.decoded
				@text.force_encoding(@mime[:content_type].charset).encode('utf-8')
			end
			@references = @mime[:references].to_s.to_s.split(/\s+/) + [@mime[:message_id].decoded]
			@followup_to_poster = false
			if @mime[:followup_to]
				if @mime[:followup_to].decoded == 'poster'
					@followup_to_poster = true
				else
					@newsgroups = @mime[:followup_to].decoded
				end
			else
				@newsgroups = @mime[:newsgroups].decoded
			end
			@subject = "Re: #{@mime[:subject].decoded.sub(/^Re:?\s*/i, '')}"
			@text = "#{@mime[:from]} wrote:\n" + @text.gsub(/^[ \t]*/, '> ')
		elsif @req.params['newsgroups']
			@title += 'Post to group ' + @req.params['newsgroups']
			@newsgroups = @req.params['newsgroups']
		else
			@title += 'Post'
			@newsgroups = ''
		end
		@template = open('views/post_form.haml').read
	rescue Exception
		@error = [500, {'Content-Type' => 'text/plain'}, $!.message]
	ensure
		return self
	end

	def post
		['fn', 'email', 'subject', 'body'].each {|k| @req.params[k] = @req.params[k].to_s.force_encoding('utf-8')}

		SimpleProtocol.new(:uri => @env['config']['server'], :default_port => 119) { |nntp|
			nntp.post
			raise 'Error sending POST command to server.' unless nntp.gets.split(' ')[0] == '340'
			lines = [
				"From: #{@req.params['fn']} <#{@req.params['email']}>",
				"Subject: #{@req.params['subject']}",
				"Newsgroups: #{@req.params['newsgroups'].to_s}",
				"Content-Type: text/plain; charset=utf-8"]
			lines << "References: #{@req.params['references'].to_s}" if @req.params['references']
			lines << "In-Reply-To: #{@req.params['in-reply-to'].to_s}" if @req.params['in-reply-to']
			lines << ""
			lines << @req.params['body'].to_s
			nntp.send_multiline(lines)
			unless (m = nntp.gets).split(' ')[0] == '240'
				raise 'Error POSTing article: ' + m
			end
		}

		if @req.params['in-reply-to']
			id = @req.params['in-reply-to'].strip.gsub(/^<|>$/,'')
			url = "http#{@env['HTTPS']?'s':''}://#{@env['HTTP_HOST']}/#{@env['config']['subdirectory']+'/' if @env['config']['subdirectory'].to_s !~ /\/*/}thread/#{id}"
			# Not really an error. Should make another way to override
			@error = [303, {'Location' => url}, url]
		else
			@title = 'New thread posted!'
			@template = "-# encoding: utf-8
!!! 5
%html(xmlns=\"http://www.w3.org/1999/xhtml\")
	!= include 'views/invisible_header.haml'

	%body
		!= include 'views/visible_header.haml'

		%p New thread posted!"
		end
	rescue Exception
		@error = [500, {'Content-Type' => 'text/plain'}, $!.message]
	ensure
		return self
	end

	def stylesheets
		super + [@env['config']['subdirectory'].to_s + '/stylesheets/post.css']
	end
end
