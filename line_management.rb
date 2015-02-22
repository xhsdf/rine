#!/usr/bin/ruby

$:.push('.')
require 'fileutils'
require 'net/http'
require 'linegui'
require 'line_logger'
require 'line_message'
require 'line_service'

def main()
	Management.new().run()
end


class Management
	PATH_STICKER = "./sticker"
	PATH_IMAGE = "./image"
	PATH_PROFILE_IMG = "./profile_img"
	LINE_OS_BASE_URL = "http://os.line.naver.jp/os"
	LINE_STICKER_BASE_URL = "http://dl.stickershop.line.naver.jp/products"
	attr_reader :gui, :logger

	def initialize
		@lineservice = LineService.new
		@lineservice.login("username", "password", "token")
		@users = {}
		@groups = {}
		@revision = @lineservice.get_last_rev

		get_available_stickers
	end
	
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
	
	def add_groups
		groupsjoined = @lineservice.get_groupids_joined
		@lineservice.get_groups(groupsjoined).each do |g|
			@users[g.id] = g.name
		end
	end

	def add_contacts
		contacts = @lineservice.get_all_contactids
		@lineservice.get_contacts(contacts).each do |c|
			@users[c.mid] = c.displayName
		end
	end

	def get_profile
		@profile = @lineservice.get_profile
		@users[@profile.mid] = @profile.displayName
	end
	
	def run()
		@gui = LineGui::LineGuiMain.new(self)
		@logger = LineLogger::Logger.new(self, "./logs")
		Thread.new do gui.run() end

		get_profile
		add_groups
		add_contacts
		@users.each do |hash, key|
			gui.add_user(hash)
			add_log(hash)
		end
		start_poll(@revision)

		while true do sleep 10 end
	end

	def start_poll(rev)
		@lineservice.start_poll(rev, method(:poll_callback))		
	end

	def process_message(message)
		#mark_message_read(message.to, message.id)

		case message.contentType
		when ContentType::NONE
			timestamp = message.createdTime.to_i / 1000
			msg = LineMessage::Message.new(message.from, message.to, message.id, timestamp, message.text, nil, nil)
			@gui.add_message(msg, false)
		when ContentType::STICKER
			if message.contentMetadata != nil && message.contentMetadata["STKID"] != nil
				pkg = message.contentMetadata["STKPKGID"]
				ver = message.contentMetadata["STKVER"]
				id = message.contentMetadata["STKID"]
				sticker = LineMessage::Sticker.new(pkg, ver, id)
			end 

			timestamp = message.createdTime.to_i / 1000
			msg = LineMessage::Message.new(message.from, message.to, message.id, timestamp, message.text, sticker, nil)
			@gui.add_message(msg, false)
		when ContentType::IMAGE
			img = LineMessage::Image.new(message.id)
			timestamp = message.createdTime.to_i / 1000
			msg = LineMessage::Message.new(message.from, message.to, message.id, timestamp, nil, nil, img)
			@gui.add_message(msg, false)
				
		else
			puts "Unknown ContentType #{message.contentType}"
			p message
		end
	end

	def poll_callback(operations)
		operations.each do |op|
			@revision = op.revision if op.revision > @revision
			case op.type
			when OpType::RECEIVE_MESSAGE
				process_message(op.message)
			when OpType::NOTIFIED_UPDATE_PROFILE
				puts "updated profile #{op.param1}"
			else


			end
		end
		start_poll(@revision)
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
		return @profile.mid
	end
	

	def get_name(user_id)
		if @users[user_id] == nil
			@users[user_id] = "undef"
		end

		return @users[user_id]
	end
	

	def get_avatar(user_id)
		path = "#{PATH_PROFILE_IMG}/"
		filename = "#{path}#{user_id}"
		if !File.exists?(filename)
			avatarurl = "#{LINE_OS_BASE_URL}/p/#{user_id}"
			puts "Downloading #{avatarurl}"

			unless File.directory?(path)
				FileUtils.mkdir_p(path)
			end
			
			File.open(filename, "wb") {|f| f.write(Net::HTTP.get(URI.parse(avatarurl)))}
		end
		return filename
	end
	
	def get_available_stickers
		@lineservice.get_available_stickers.productList.each do |sticker|
			puts "package #{sticker.packageId.to_s} version #{sticker.version.to_s}"
			#"#{LINE_STICKER_BASE_URL}/#{ver/1000000}/#{ver/1000}/#{ver%1000}/#{set}/WindowsPhone/productInfo.meta"

		end
	end

	def mark_message_read(to, messageid)
		@lineservice.send_chat_checked(to, messageid)
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
	

	def get_image(message, preview = false)
		path = PATH_IMAGE
		filename = "#{path}/#{message.id}#{preview ? ".thumb" : ""}"
		if !File.exists?(filename)
			unless File.directory?(path)
				FileUtils.mkdir_p(path)
			end
			File.open(filename, "wb") {|f| f.write(@lineservice.get_image(message.id, preview))}
		end
		return filename
	end
		
		
	def send_message(to, text, sticker = nil, image = nil)
		Thread.new do
			sticker = LineMessage::Sticker.new(1000963, 2, 94996)
			
			message = LineMessage::Message.new(get_own_user_id(), to, nil, Time.now.to_i, text, sticker, image)
			p message
			response = @lineservice.send_message(message)
			if response.nil?
				raise "Could not deliver message"
			end		

			process_message(response)
		end
	end
end

main()
