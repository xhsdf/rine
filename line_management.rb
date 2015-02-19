#!/usr/bin/ruby

<<<<<<< HEAD
require './linegui.rb'
require './line_logger.rb'
require './line_message.rb'
require 'fileutils'
require 'net/http'
=======
$:.push('.')
require 'linegui'
require 'line_logger'
require 'line_message'
>>>>>>> 4e59c4093767436c688a8a693c24f6bec7228e1d

def main()
	Management.new().run()
end


class Management
	PATH_STICKER = "./sticker"
	LINE_STICKER_BASE_URL = "http://dl.stickershop.line.naver.jp/products"
	attr_reader :gui, :logger
	
	def open_uri(uri)
		if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
			system "start #{uri}"
		lsif RbConfig::CONFIG['host_os'] =~ /darwin/
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
		@gui = LineGui::LineGuiMain.new(self)
		@logger = LineLogger::Logger.new(self, "./logs")
		Thread.new do gui.run() end
		
		gui.add_user(0)
		gui.add_user(4)
		add_log(0)
		add_log(4)
	
	
		if true
			#~ sleep 2
			#~ add_message(LineMessage::Message.new(2, 4, 9001, Time.now.to_i, "Poi?", nil, nil))
			#~ add_message(LineMessage::Message.new(1, 4, 9001, Time.now.to_i, "Poi?", nil, nil))
			#~ add_message(LineMessage::Message.new(0, 4, 9001, Time.now.to_i, "Poi?", nil, nil))
			#~ 
			#~ sleep 2
			#~ add_message(LineMessage::Message.new(2, 0, 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 7), nil))
			#~ sleep 1
			#~ add_message(LineMessage::Message.new(0, 2, 9001, Time.now.to_i, "Poi?", nil, nil))
			#~ #~ gui.add_message(LineMessage::Message.new(0, 2, 9001, Time.now.to_i, "Poi?Poi?Poi?Poi?Poi?Poi?Poi?Poi?", nil, nil))
			#~ add_message(LineMessage::Message.new(2, 0, 9001, Time.now.to_i, "Poi?", nil, nil))
			#~ sleep 1	
			#~ add_message(LineMessage::Message.new(2, 0, 9001, Time.now.to_i, "Das http://oreno.soup.io/ ist ein Test<>: http://asset-5.soup.io/asset/9978/6216_54e9.jpeg", nil, nil))
			#~ add_message(LineMessage::Message.new(2, 0, 9001, Time.now.to_i, "Am besten ist es, den Leuten Geschichten zu erzählen, die absolut sinnlos sind, so wie damals, als ich mit der Fähre nach Shelbyville rübergefahren bin. Alles, was ich brauchte, war ein neuer Absatz für meinen Schuh, also beschloss ich nach Morganville rüber zu fahren, was zu damaliger Zeit aber noch Shelbyville hieß. Da hab ich mir eine Zwiebel an den Gürtel gehängt, das war damals übrigens üblich. Und die Überfahrt hat 5 Cent gekostet und auf dem 5 Cent Stück war damals noch ein wunderschöner Hummelschwarm abgebildet. Gib mir 5 Hummelschwärme für nen Viertel-Dollar, hieß es. Wo waren wir stehen geblieben?  Achja, der springende Punkt war, dass ich ne Zwiebel am Gürtel hatte, was damals absolut üblich war. Es gab keine weißen Zwiebeln, weil Krieg war.", nil, nil))
			#~ sleep 2	
			#~ add_message(LineMessage::Message.new(1, 2, 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 7), nil))
			#~ add_message(LineMessage::Message.new(2, 1, 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 7), nil))
		end
		
		
		while true do
			sleep 5
			add_message(LineMessage::Message.new(0, 2, 9001, Time.now.to_i, nil, LineMessage::Sticker.new(3897, 1, 4164179), nil))
			sleep 1
			add_message(LineMessage::Message.new(0, 2, 9001, Time.now.to_i, "Poi?", nil, nil))
			add_message(LineMessage::Message.new(0, 2, 9001, Time.now.to_i, "Poi?", nil, nil))
			sleep 1
			add_message(LineMessage::Message.new(2, 0, 9001, Time.now.to_i, "Poi?", nil, nil))
		end
		
		
		while true do sleep 10 end
	end
	
	
	def add_log(user_id)
		@logger.get_messages(user_id).each do |message|
			@gui.add_message(message, true)
		end
		#~ @gui.conversations[user_id].scroll_to_bottom()
	end
	
	
	def get_users(group_id)
		return 0, 1, 2, 3 if group_id == 4
		return []
	end

	def get_own_user_id()
		return 2
	end
	

	def get_name(user_id)
		return ["Poi", "Hans", "Peter", "Frank", "Burgdorf"][user_id]
	end
	

	def get_avatar(user_id)
		#~ sleep 2
		return "./files/poi.jpg" if user_id == 0
		return "./files/avatar2.jpg" if user_id == 1
		return "./files/avatar.png"
	end
	

	def get_sticker(message)
		set = message.sticker.set_id.to_i
		ver = message.sticker.version.to_i
		id = message.sticker.id.to_i

		path = "#{PATH_STICKER}/#{set}/#{ver}/"
		filename = "#{path}#{id}.png"
		if !File.exists?(filename)
			stickerurl = "#{LINE_STICKER_BASE_URL}/#{ver/1000000}/#{ver/1000}/#{ver%1000}/#{set}/WindowsPhone/stickers/#{id}.png"
			puts "Downloading #{stickerurl}"

			unless File.directory?(path)
				FileUtils.mkdir_p(path)
			end
			
			File.open(filename, "wb") {|f| f.write(Net::HTTP.get(URI.parse(stickerurl)))}
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
		message_id = 9001
		
		add_message(LineMessage::Message.new(get_own_user_id(), to, message_id, Time.now.to_i, text, sticker, image))
	end
end

main()
