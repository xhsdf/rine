#!/usr/bin/ruby

$:.push('.')
require 'fileutils'
require 'net/http'
require 'linegui'
require 'line_logger'
require 'line_message'

def main()
	Management.new().run()
end


class Management
	PATH_STICKER = "./sticker"
	LINE_STICKER_BASE_URL = "http://dl.stickershop.line.naver.jp/products"
	MAX_DOWNLOADS = 10
	attr_reader :gui, :logger, :downloads
	
	def open_uri(uri)
		if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
			system "start #{uri}"
		elsif RbConfig::CONFIG['host_os'] =~ /darwin/
			system "open #{uri}"
		elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
			system "xdg-open #{uri} &> /dev/null"
		end
	end
	
	def add_message(message)
			@gui.add_message(message, false)
			@logger.add_message(message)
	end
	
	
	def run()
		@downloads = 0
		@gui = LineGui::LineGuiMain.new(self)
		@logger = LineLogger::Logger.new(self, "./logs")
		Thread.new do gui.run() end
		
		gui.add_user("a0")
		gui.add_user("a4")
		add_log("a0")
		add_log("a0")
		
		@gui.add_sticker_set(get_sticker_set(3897, 1))
	
	

		sleep 2
		add_message(LineMessage::Message.new("a2", "a4", 9001, Time.now.to_i, "Poi?", nil, nil))
		add_message(LineMessage::Message.new("a1", "a4", 9001, Time.now.to_i, "Poi?", nil, nil))
		add_message(LineMessage::Message.new("a0", "a4", 9001, Time.now.to_i, "Poi?", nil, nil))
		
		sleep 2
		add_message(LineMessage::Message.new("a2", "a0", 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 4164182), nil))
		sleep 1
		add_message(LineMessage::Message.new("a0", "a2", 9001, Time.now.to_i, "Poi?", nil, nil))
		#~ add_message(LineMessage::Message.new("a0", "a2", 9001, Time.now.to_i, "Poi?Poi?Poi?Poi?Poi?Poi?Poi?Poi?", nil, nil))
		add_message(LineMessage::Message.new("a2", "a0", 9001, Time.now.to_i, "Poi?", nil, nil))
		sleep 1	
		add_message(LineMessage::Message.new("a2", "a0", 9001, Time.now.to_i, "Das http://oreno.soup.io/ ist ein Test<>: http://asset-5.soup.io/asset/9978/6216_54e9.jpeg", nil, nil))
		add_message(LineMessage::Message.new("a2", "a0", 9001, Time.now.to_i, "Am besten ist es, den Leuten Geschichten zu erzählen, die absolut sinnlos sind, so wie damals, als ich mit der Fähre nach Shelbyville rübergefahren bin. Alles, was ich brauchte, war ein neuer Absatz für meinen Schuh, also beschloss ich nach Morganville rüber zu fahren, was zu damaliger Zeit aber noch Shelbyville hieß. Da hab ich mir eine Zwiebel an den Gürtel gehängt, das war damals übrigens üblich. Und die Überfahrt hat 5 Cent gekostet und auf dem 5 Cent Stück war damals noch ein wunderschöner Hummelschwarm abgebildet. Gib mir 5 Hummelschwärme für nen Viertel-Dollar, hieß es. Wo waren wir stehen geblieben?  Achja, der springende Punkt war, dass ich ne Zwiebel am Gürtel hatte, was damals absolut üblich war. Es gab keine weißen Zwiebeln, weil Krieg war.", nil, nil))
		sleep 2	
		add_message(LineMessage::Message.new("a1", "a2", 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 4164182), nil))
		add_message(LineMessage::Message.new("a2", "a1", 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 4164182), nil))

		
		
		while not @gui.closed do
			sleep 5
			add_message(LineMessage::Message.new("a0", "a2", 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 4164182), nil))
			sleep 1
			add_message(LineMessage::Message.new("a0", "a2", 9001, Time.now.to_i, "Poi?", nil, nil))
			add_message(LineMessage::Message.new("a0", "a2", 9001, Time.now.to_i, "Poi?", nil, nil))
			sleep 1
			add_message(LineMessage::Message.new("a2", "a0", 9001, Time.now.to_i, "Poi?", nil, nil))
		end
		
		
		while not @gui.closed do sleep 2 end
	end
	
	
	def add_log(user_id)
		@logger.get_messages(user_id).each do |message|
			@gui.add_message(message, true)
		end
		#~ @gui.conversations[user_id].scroll_to_bottom()
	end
	
	
	def get_users(group_id)
		return "a0", "a1", "a2", "a3" if group_id == "a4"
		return []
	end

	def get_own_user_id()
		return "a2"
	end
	

	def get_name(user_id)
		return "Poi" if  user_id == "a0"
		return "Hans" if  user_id == "a1"
		return "Peter" if  user_id == "a2"
		return "Frank" if  user_id == "a3"
		return "Burgdorf" if  user_id == "a4"
	end
	

	def get_avatar(user_id)
		#~ sleep 2
		return "./files/poi.jpg" if user_id == "a0"
		return "./files/avatar2.jpg" if user_id == "a1"
		return "./files/avatar.png"
	end
	


	def get_sticker(sticker)
		set = sticker.set_id.to_i
		ver = sticker.version.to_i
		id = sticker.id.to_i

		path = "#{PATH_STICKER}/#{set}/#{ver}/"
		filename = "#{path}#{id}.png"
		if !File.exists?(filename)
			while @downloads > MAX_DOWNLOADS
				sleep 0.2
			end
			@downloads += 1
			begin
				stickerurl = "#{LINE_STICKER_BASE_URL}/#{ver/1000000}/#{ver/1000}/#{ver%1000}/#{set}/WindowsPhone/stickers/#{id}.png"
				puts "Downloading #{stickerurl}"

				unless File.directory?(path)
					FileUtils.mkdir_p(path)
				end
				
				File.open(filename, "wb") {|f| f.write(Net::HTTP.get(URI.parse(stickerurl)))}
			rescue
			ensure
				@downloads -= 1
			end
		end
		return filename
	end
	
	
	def get_available_stickers() # return Array of LineStickerSet
		stickersets = []
		
		stickers = []
		(0..20).each do |i|
			stickers << LineMessage::Sticker.new(3897, 1, i)
		end
		
		stickersets << LineMessage::StickerSet(3897, 1, stickers)
	end
	

	def get_image(message, preview = false)
		return "./files/image_preview.png" if preview
		return "./files/image.png"
	end
		
		
	def send_message(to, text, sticker = nil, image = nil)
		puts text
		message_id = "9001"
		
		add_message(LineMessage::Message.new(get_own_user_id(), to, message_id, Time.now.to_i, text, sticker, image))
	end
end

require 'json'
require 'open-uri'

LINE_STICKER_BASE_URL = "http://dl.stickershop.line.naver.jp/products"


def get_sticker_set(set_id, version)
	json_string = open("#{LINE_STICKER_BASE_URL}/#{version/1000000}/#{version/1000}/#{version%1000}/#{set_id}/WindowsPhone/productInfo.meta").read

	json = JSON.parse(json_string)

	stickers = []
	json["stickers"].each do |sticker|
		stickers << LineMessage::Sticker.new(set_id, version, sticker["id"])
	end
	name = json["title"]["en"] || json["title"]["ja"] || "undef"
	
	return LineMessage::StickerSet.new(set_id, name, version, stickers)
end

main()
