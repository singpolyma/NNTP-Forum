require 'controllers/application.rb'
require 'lib/nntp'
require 'mail'

class IndexController < ApplicationController
	def initialize(env)
		super
		SimpleProtocol.new(:uri => env['config']['server'], :default_port => 119) { |nntp|
			nntp.group @env['config']['server'].path[1..-1]
			max = nntp.gets.split(' ')[3]
			@threads = NNTP::get_threads(nntp, (@req['start'] || max).to_i, 10, @req['seen'])
			@threads.each {|thread|
				thread[:mime] = Mail::Message.new(thread)
				thread[:subject] = thread[:mime][:subject].decoded
				thread[:from] = thread[:mime][:from].decoded
				(thread[:newsgroups] || []).reject! {|n| n == @env['config']['server'].path[1..-1]}
			}
		}
	rescue Exception
		@error = [500, {'Content-Type' => 'text/plain'}, 'General Error.']
	end

	attr_reader :threads

	def title
		@env['config']['title']
	end

	def template
		open('views/index.haml').read
	end

	def stylesheets
		super + [@env['config']['subdirectory'].to_s + '/stylesheets/index.css']
	end
end
