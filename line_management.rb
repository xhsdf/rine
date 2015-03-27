$:.push('.')
require 'fileutils'
require 'net/http'
require 'linegui'
require 'line_logger'
require 'line_message'
require 'line_service'
require 'json'
require 'open-uri'


class Management
	PATH_STICKER = "./sticker"
	PATH_IMAGE = "./image"
	PATH_PROFILE_IMG = "./profile_img"
	LINE_OS_BASE_URL = "http://os.line.naver.jp/os"
	LINE_STICKER_BASE_URL = "http://dl.stickershop.line.naver.jp/products"
	MAX_DOWNLOADS = 10
	attr_reader :gui, :logger, :downloads, :conversations

	def initialize(username, password, token)
		@lineservice = LineService.new
		@lineservice.login(username, password, token)
		@users = {}
		@groups = {}
		@conversations = {}
		#~ @revision = @lineservice.get_last_rev
		@downloads = 0
	end


	def open_uri(uri)
		if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
			system "start #{uri}"
		elsif RbConfig::CONFIG['host_os'] =~ /darwin/
			system "open #{uri}"
		elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
			require 'shellwords'
			system "xdg-open #{Shellwords.escape(uri)} &> /dev/null"
		end
	end


	def add_message(message)
		@gui.add_message(message)
		conv_id = get_conversation_id(message.from, message.to)
		if conversations[conv_id].nil?
			conversations[conv_id] = []
		end
		conversations[conv_id] << message
		@logger.add_message(message)
	end
	
	
	def get_conversation_id(from, to)
		id = nil
		if to == get_own_user_id()
			id = from
		else
			id = to
		end
		return id
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
	
	
	def get_users(group_id)
		return [] # TODO
	end
	
	
	def get_profile
		@profile = @lineservice.get_profile
		@users[@profile.mid] = @profile.displayName
	end

	
	def run()
		@gui = LineGui::LineGuiMain.new(self)
		Thread.new do gui.run() end
		@logger = LineLogger::Logger.new(self, "./logs")

		Thread.new do
			@lineservice.get_available_stickers.productList.each do |sticker|
				#~ puts "package #{sticker.packageId.to_s} version #{sticker.version.to_s}"
				@gui.add_sticker_set(get_sticker_set(sticker.packageId, sticker.version))				
			end
		end

		get_profile
		add_groups
		add_contacts
		@users.each do |hash, key|
			unless hash == get_own_user_id()
				gui.add_user(hash)
				add_log(hash)
			end
		end
		
		@revision = @logger.revision || @lineservice.get_last_rev
		
		start_poll(@revision)

		while not @gui.closed do sleep 2 end
	end


	def start_poll(rev)
		@lineservice.start_poll(rev, method(:poll_callback))		
	end


	def process_message(message, revision)
		#mark_message_read(message.to, message.id)

		case message.contentType
		when ContentType::NONE
			timestamp = message.createdTime.to_i / 1000
			msg = LineMessage::Message.new(message.from, message.to, message.id, timestamp, message.text, nil, nil, revision)
			add_message(msg)
		when ContentType::STICKER
			if message.contentMetadata != nil && message.contentMetadata["STKID"] != nil
				pkg = message.contentMetadata["STKPKGID"]
				ver = message.contentMetadata["STKVER"]
				id = message.contentMetadata["STKID"]
				sticker = LineMessage::Sticker.new(pkg, ver, id)
			end 

			timestamp = message.createdTime.to_i / 1000
			msg = LineMessage::Message.new(message.from, message.to, message.id, timestamp, message.text, sticker, nil, revision)
			add_message(msg)
		when ContentType::IMAGE
			img = LineMessage::Image.new(message.id)
			timestamp = message.createdTime.to_i / 1000
			msg = LineMessage::Message.new(message.from, message.to, message.id, timestamp, nil, nil, img, revision)
			add_message(msg)				
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
				process_message(op.message, op.revision)
			when OpType::SEND_MESSAGE
				unless (op.message.contentType == ContentType::IMAGE)
					process_message(op.message, op.revision)
				end
			when OpType::SEND_CONTENT
				process_message(op.message, op.revision)
			when OpType::NOTIFIED_UPDATE_PROFILE
				puts "updated profile #{op.param1}"
			when OpType::NOTIFIED_READ_MESSAGE
				notify_read_message(op.param3, op.param2, op.param1)
			else
			end
		end
		start_poll(@revision)
	end


	def notify_read_message(message_id, reader_id, conv_id)
		Thread.new do
			begin
				unless @conversations[conv_id].nil?
					(@conversations[conv_id].select do |message| message.id <= message_id and message.from == get_own_user_id() end).each do |message|
						@gui.conversations[conv_id].messages[message.id].add_read_by(reader_id)
					end
				end
			rescue Exception => e
				puts e
			end
		end
	end
	
	
	def add_log(user_id)
		@logger.get_messages(user_id).each do |message|
			@gui.add_message(message)
		end
	end


	def get_own_user_id()
		return @profile.mid
	end
	

	def get_name(user_id)
		if @users[user_id] == nil
			return "undef"
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


	def mark_message_read(to, messageid)
		@lineservice.send_chat_checked(to, messageid)
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
	

	def get_image(message, preview = false)
		path = PATH_IMAGE
		filename = "#{path}/#{message.id}#{preview ? ".thumb" : ""}"
		if !File.exists?(filename)
			unless File.directory?(path)
				FileUtils.mkdir_p(path)
			end
			
			image = preview ? @lineservice.get_image_preview(message.id) : @lineservice.get_image_obs(message.id)
			unless image.nil?
				File.open(filename, "wb") { |f| f.write(image) }
			else
				puts "Image #{message.id} not available"
				return nil
			end
		end
		return filename
	end
		
		
	def send_message(to, text, sticker = nil, image = nil)
		Thread.new do			
			message = LineMessage::Message.new(get_own_user_id(), to, nil, Time.now.to_i, text, sticker, image)
			response = @lineservice.send_message(message)
			if response.nil?
				raise "Could not deliver message"
			end
		end
	end
	
	def upload_image(id, filename)
		@lineservice.upload(id, filename)
	end
end
