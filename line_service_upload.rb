$:.push('.')

require 'json'
require 'net/http'
require 'fileutils'

class LineServiceUpload
	LINE_UPLOAD_URI = URI.parse("https://obs.line-apps.com:443/talk/m/upload.nhn")
	DELIMITER = "----wpYGYCMYYCW--"
	
	class OBSParam
		attr_accessor :ver, :oid, :type, :name, :size, :range
		
		def to_json
			{'ver' => @ver, 'oid' => @oid, 'type' => @type, 'name' => @name, 'size' => @size, 'range' => @range}.to_json
		end
	end
	
	def initialize(token, client)
		@token = token
		@client = client
	end
	
	def create_header(id, filename, range)
		obs = OBSParam.new
		obs.ver = "1.0"
		obs.oid = id.to_s
		obs.type = "image"
		obs.name = filename
		obs.range = range
		header = "\r\n--#{DELIMITER}\r\nContent-Disposition: form-data; name=\"params\"\r\n\r\n#{obs.to_json}\r\n"
		header += "\r\n--#{DELIMITER}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\nContent-Type: application/octet-stream\r\n\r\n"
		return header
	end
	
	def create_footer
		return "\r\n--#{DELIMITER}--\r\n"
	end
	
	def create_data(id, filename)
		image = open(filename, "rb") {|io| io.read}
		range = "bytes 0-#{image.length - 1}/#{image.length}"
		data = create_header(id, File.basename(filename), range)
		data += image
		data += create_footer
		return data
	end
	
	def upload(id, filename)
		puts "Start upload"
		http = Net::HTTP.new(LINE_UPLOAD_URI.host, LINE_UPLOAD_URI.port)
		res = http.start do |s|
			begin
			header = {"Content-Type" => "multipart/form-data; boundary=#{DELIMITER}",
					  "X-Line-Access" => @token,
					  "X-Line-Application" => @client,
					  "User-Agent" => @client}
			data = create_data(id, filename)

			s.post(LINE_UPLOAD_URI.path, data, header)
			rescue Exception => e
			p e
			end
		end
	end
end
