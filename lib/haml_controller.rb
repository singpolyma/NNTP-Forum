require 'haml'

# Hack to make ruby 1.9.0 work with new haml
unless Encoding.respond_to?:default_internal
	class Encoding
		def self.default_internal; end
	end
end
unless defined?(Encoding::UndefinedConversionError)
	class Encoding::UndefinedConversionError; end
end

class HamlController
	def title
		'Page Title'
	end

	def stylesheets
		[]
	end

	def each_tag(array, haml, args={})
		array.map do |item|
			args[:item] = item
			engine = Haml::Engine.new(haml, :attr_wrapper => '"', :escape_html => true)
			engine.render(self, args)
		end.join("\n")
	end

	def include(file, args={})
		engine = Haml::Engine.new(open(file).read, :attr_wrapper => '"', :escape_html => true)
		engine.render(self, args)
	end

	def include_for_each(array, file, args={})
		array.map do |item|
			args[:item] = item
			self.include(file, args)
		end.join("\n")
	end

	def render(args={})
		engine = Haml::Engine.new(template, :attr_wrapper => '"', :escape_html => true)
		[200, {'Content-Type' => "#{args[:content_type] || 'text/html; charset=utf-8'}"}, engine.render(self, args)]
	end
end
