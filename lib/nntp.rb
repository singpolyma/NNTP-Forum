require 'lib/simple_protocol'
require 'uri'
require 'time'

module NNTP

	def self.overview_to_hash(line)
		line = line.force_encoding('utf-8').split("\t")
		{
			:article_num => line[0].to_i,
			:subject     => line[1],
			:from        => line[2],
			:date        => Time.parse(line[3]),
			:message_id  => line[4],
			:references  => line[5],
			:bytes       => line[6].to_i,
			:lines       => line[7].to_i
		}
	end

	def self.headers_to_hash(headers)
		headers = headers.inject({}) {|c, line|
			line = line.force_encoding('utf-8').split(/:\s+/,2)
			c[line[0].downcase.sub(/-/,'_').intern] = line[1]
			c
		}
		headers[:date] = Time.parse(headers[:date]) if headers[:date]
		headers[:newsgroups] = headers[:newsgroups].split(/,\s*/) if headers[:newsgroups]
		headers[:article_num] = headers[:xref].split(':',2)[1].to_i if !headers[:article_num] && headers[:xref]
		headers
	end

	def self.get_thread(nntp, message_id, start, max, num=10, seen=nil)
		seen ||= []
		buf = []
		while buf.length < num && start < max
			nntp.over "#{start+1}-#{start+(num*15)}"
			raise 'Error getting threads.' unless nntp.gets.split(' ')[0] == '224'
			buf += nntp.gets_multiline.select {|line|
				line = line.split("\t")
				line[5].to_s.split(/,\s*/)[0] == message_id && !seen.index(line[4])
			}.map {|line| overview_to_hash line }
			start += num*15
		end
		buf.sort {|a,b| a[:date] <=> b[:date]}.slice(0,num)
	end

	def self.get_threads(nntp, max, num=10, seen=nil)
		seen ||= []
		threads = {}
		start = max - num*2
		start = 1 if start < 1 || num == 0 # Never be negative, and get all when num=0
		while threads.length < num && start > 0
			nntp.over "#{start}-#{max}"
			raise 'Error getting threads.' unless nntp.gets.split(' ')[0] == '224'
			nntp.gets_multiline.each do |line|
				line = overview_to_hash(line)
				if line[:references].to_s == ''
					next if seen.include?(line[:message_id])
					threads[line[:message_id]] ||= {}
					threads[line[:message_id]].merge!(line)
				else
					id = line[:references].to_s.scan(/<[^>]+>/)
					id = id[0] if id
					next if seen.include?(id)
					threads[id] ||= {}
					threads[id].merge!({:updated => line[:date]})
				end
			end
			start -= num*2
		end
		threads.inject({}) do |h, (id, thread)|
			if thread[:subject]
				h[id] = thread
			else
				oldid = id
				begin
					nntp.head(id)
					raise 'Error getting threads.' unless nntp.gets.split(' ')[0] == '221'
					thread.delete(:references)
					thread.merge!(headers_to_hash(nntp.gets_multiline))
					id = thread[:references].to_s.scan(/<[^>]+>/)
					id = id[0] if id
					break if id == oldid # Detect infinite loop
					oldid = id
				end while thread[:references].to_s != ''
				h[id] = thread
			end
			h
		end.values.sort {|a,b| (b[:updated] || b[:date]) <=> (a[:updated] || a[:date])}.slice(0,num)
	end

end
