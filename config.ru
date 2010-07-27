#!/usr/bin/env rackup
# encoding: utf-8
#\ -E deployment

require 'rack/accept_media_types'
#require 'rack/supported_media_types'
require 'lib/path_info_fix'
require 'lib/subdirectory_routing'
require 'http_router'
require 'yaml'
require 'uri'

$config = YAML::load_file('config.yaml')

use Rack::Reloader
use Rack::ContentLength
use PathInfoFix
use Rack::Static, :urls => ['/stylesheets'] # Serve static files if no real server is present
use SubdirectoryRouting, $config['subdirectory'].to_s
#use Rack::SupportedMediaTypes, ['application/xhtml+xml', 'text/html', 'text/plain']

run HttpRouter.new {
	$config['server'] = URI::parse($config['server'])

	get('/thread/:message_id/?').to { |env|
		env['config'] = $config
		require 'controllers/thread'
		ThreadController.new(env).render
	}

	get('/?').to { |env|
		env['config'] = $config
		require 'controllers/index'
		IndexController.new(env).render
	}
}
