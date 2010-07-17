require 'controllers/application.rb'
require 'lib/nntp'

class IndexController < ApplicationController
	def initialize(env)
		@env = env
		SimpleProtocol.new(:uri => env['config']['server'], :default_port => 119) { |nntp|
			nntp.group @env['config']['server'].path[1..-1]
			max = nntp.gets.split(' ')[3].to_i
			@threads = NNTP::get_threads(nntp, max)
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
