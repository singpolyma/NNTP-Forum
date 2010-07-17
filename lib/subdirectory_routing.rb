# This middleware chops some subdirectory off the front of the request path so routing will work

class SubdirectoryRouting
	def initialize(app, subdir)
		@app = app
		subdir = subdir[1..-1] if subdir[0] == '/'
		@subdir = subdir
	end

	def call(env)
		env['PATH_INFO'] = env['PATH_INFO'].sub(/^\/*#{@subdir}/,'')
		env['SCRIPT_URL'] = env['SCRIPT_URL'].sub(/^\/*#{@subdir}/,'')
		env['REDIRECT_URL'] = env['REDIRECT_URL'].sub(/^\/*#{@subdir}/,'')
		env['REQUEST_URI'] = env['REQUEST_URI'].sub(/^\/*#{@subdir}/,'')
		@app.call(env)
	end
end
