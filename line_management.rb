#!/usr/bin/ruby

require './linegui.rb'
require './line_logger.rb'

def main()
	Management.new().run()
end


class Management
	attr_reader :gui, :logger
	
	def open_url(url)
		if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
			system "start #{url}"
		lsif RbConfig::CONFIG['host_os'] =~ /darwin/
			system "open #{url}"
		elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
			system "xdg-open #{url} &> /dev/null"
		end
	end
	
	def add_message(message, log = false)
			@gui.add_message(message, log)
			@logger.add_message(message)
	end
	
	
	def run()
		@gui = LineGui::LineGuiMain.new(self)
		@logger = LineLogger::Logger.new(self, "/home/xhsdf/programming/ruby/line/logs")
		Thread.new do gui.run() end
		
		gui.add_user(0)
		gui.add_user(4)
		add_log(0)
		add_log(4)
	
	
		if false
			sleep 2
			add_message(LineGui::LineMessage.new(2, 4, 9001, Time.now.to_i, "Poi?", nil, nil))
			add_message(LineGui::LineMessage.new(1, 4, 9001, Time.now.to_i, "Poi?", nil, nil))
			add_message(LineGui::LineMessage.new(0, 4, 9001, Time.now.to_i, "Poi?", nil, nil))
			
			sleep 2
			add_message(LineGui::LineMessage.new(2, 0, 9001, Time.now.to_i, nil, LineGui::LineSticker.new(3897, 1, 7), nil))
			sleep 1
			add_message(LineGui::LineMessage.new(0, 2, 9001, Time.now.to_i, "Poi?", nil, nil))
			#~ gui.add_message(LineGui::LineMessage.new(0, 2, 9001, Time.now.to_i, "Poi?Poi?Poi?Poi?Poi?Poi?Poi?Poi?", nil, nil))
			add_message(LineGui::LineMessage.new(2, 0, 9001, Time.now.to_i, "Poi?", nil, nil))
			sleep 1	
			add_message(LineGui::LineMessage.new(2, 0, 9001, Time.now.to_i, "Das http://oreno.soup.io/ ist ein Test<>: http://asset-5.soup.io/asset/9978/6216_54e9.jpeg", nil, nil))
			add_message(LineGui::LineMessage.new(2, 0, 9001, Time.now.to_i, "Am besten ist es, den Leuten Geschichten zu erzählen, die absolut sinnlos sind, so wie damals, als ich mit der Fähre nach Shelbyville rübergefahren bin. Alles, was ich brauchte, war ein neuer Absatz für meinen Schuh, also beschloss ich nach Morganville rüber zu fahren, was zu damaliger Zeit aber noch Shelbyville hieß. Da hab ich mir eine Zwiebel an den Gürtel gehängt, das war damals übrigens üblich. Und die Überfahrt hat 5 Cent gekostet und auf dem 5 Cent Stück war damals noch ein wunderschöner Hummelschwarm abgebildet. Gib mir 5 Hummelschwärme für nen Viertel-Dollar, hieß es. Wo waren wir stehen geblieben?  Achja, der springende Punkt war, dass ich ne Zwiebel am Gürtel hatte, was damals absolut üblich war. Es gab keine weißen Zwiebeln, weil Krieg war.", nil, nil))
			sleep 2	
			add_message(LineGui::LineMessage.new(1, 2, 9001, Time.now.to_i, nil, LineGui::LineSticker.new(3897, 1, 7), nil))
			add_message(LineGui::LineMessage.new(2, 1, 9001, Time.now.to_i, nil, LineGui::LineSticker.new(3897, 1, 7), nil))
		end
		
		
		while true do
			sleep 5
			add_message(LineGui::LineMessage.new(0, 2, 9001, Time.now.to_i, nil, LineGui::LineSticker.new(3897, 1, 7), nil))
			sleep 1
			add_message(LineGui::LineMessage.new(0, 2, 9001, Time.now.to_i, "Poi?", nil, nil))
			sleep 1
			add_message(LineGui::LineMessage.new(2, 0, 9001, Time.now.to_i, "Poi?", nil, nil))
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
	

	#add_user
	#add_group

	def get_own_user_id()
		return 2
	end
	

	def get_name(user_id)
		return ["Poi", "Hans", "Peter", "Frank", "Burgdorf"][user_id]
	end
	

	def get_avatar(user_id)
		return "/home/xhsdf/programming/ruby/line/files/poi.jpg" if user_id == 0
		return "/home/xhsdf/programming/ruby/line/files/avatar2.jpg" if user_id == 1
		return "/home/xhsdf/programming/ruby/line/files/avatar.png"
	end
	

	def get_sticker(set_id, version, id)
		return "/home/xhsdf/programming/ruby/line/files/sticker.png"
	end
	

	def get_image(image_id, preview = false)
		return "/home/xhsdf/programming/ruby/line/files/image_preview.png" if preview
		return "/home/xhsdf/programming/ruby/line/files/image.png"
	end
end

main()