# This middleware just makes sure all path env vars are set

class PathInfoFix
	def initialize(app)
		@app = app
	end

	def call(env)
		env['PATH_INFO'] ||= env['SCRIPT_URL']
		env['PATH_INFO'] ||= env['REDIRECT_URL']
		env['PATH_INFO'] ||= env['REQUEST_URI']
		env['SCRIPT_URL'] ||= env['PATH_INFO']
		env['REDIRECT_URL'] ||= env['PATH_INFO']
		env['REQUEST_URI'] ||= env['PATH_INFO']
		@app.call(env)
	end
end
