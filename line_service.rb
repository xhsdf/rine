$:.push('.')
require 'line_service_upload'
$:.push('gen-rb')
require 'thrift'
require 'talk_service'
require 'shop_service'
require 'net/http'
require 'json'
require 'openssl'


class LineService

	LINE_CLIENT = "DESKTOPWIN\t3.7.0\tWINDOWS\t5.1.2600-XP-x64"
	LINE_BASE_URL = "https://gd2.line.naver.jp/"
	LINE_OS_BASE_URL = "http://os.line.naver.jp/os"
	LINE_OBS_BASE_URL = "https://obs-de.line-apps.com:443"
	LINE_TALK_URI = URI.parse(LINE_BASE_URL + "api/v4/TalkService.do")
	LINE_CERT_URI = URI.parse(LINE_BASE_URL + "Q")
	LINE_P4_URI = URI.parse(LINE_BASE_URL + "P4")
	LINE_SHOP_URI = URI.parse(LINE_BASE_URL + "SHOP4")
	LINE_LOGIN_URI = URI.parse(LINE_BASE_URL + "authct/v1/keys/line")

	class ThriftService
		attr_reader :service
		def initialize(uri, serviceclass)
			@transport = Thrift::HTTPClientTransport.new(uri)
			@transport.add_headers('X-Line-Application' => LINE_CLIENT)
			protocol = Thrift::CompactProtocol.new(@transport)
			@service = serviceclass.new(protocol)
		end

		def set_token(token)
			@transport.add_headers('X-Line-Access' => token)
		end
	end
	
	def initialize
		@talkservice = ThriftService.new(LINE_TALK_URI, TalkService::Client)
		@shopservice = ThriftService.new(LINE_SHOP_URI, ShopService::Client)
		@p4service = ThriftService.new(LINE_P4_URI, TalkService::Client)
	end

	def login(username, password, authtoken)
		token = login_with_token(authtoken) unless authtoken.nil?
		if token.nil?
			token = login_with_password(username, password)
		end

		@talkservice.set_token(token)		
		@p4service.set_token(token)		
		@shopservice.set_token(token)		
		@authtoken = token
		puts @authtoken if authtoken.nil?
		return token
	end
	
	def login_with_token(token)
		@talkservice.set_token(token)
		begin
			@talkservice.service.getProfile.mid
			return token
		rescue TalkException => e
			if e.code != ErrorCode::AUTHENTICATION_FAILED
				p e
				raise "Unknown error"
			end

			puts "Authentication with token failed"
			return nil
		end
	end

	def login_with_password(username, password)
		rsakey = get_rsa_login_key(username, password)

		begin
			logincred = @talkservice.service.loginWithIdentityCredentialForCertificate(IdentityProvider::LINE, username, password, true, "127.0.0.1", "", rsakey)
		rescue TalkException => e
			p e
			if e.code == ErrorCode::INVALID_IDENTITY_CREDENTIAL
				raise "Account ID or password is invalid"
			end

			raise "Unknown error"
		end
		
		return logincred.authToken unless logincred.authToken.nil?

		if logincred.pinCode.nil? || logincred.verifier.nil?
			p logincred
			raise "Unknown error"
		end
		
		return login_with_verifier(logincred.pinCode, logincred.verifier)
	end

	def login_with_verifier(pin, verifier)
		puts "Enter PIN code #{pin} within 2 minutes"

		begin
			# Wait for response (blocking operation)
			req = Net::HTTP::Get.new(LINE_CERT_URI.path)
			req['X-Line-Access'] = verifier
			res = Net::HTTP.start(LINE_CERT_URI.hostname, LINE_CERT_URI.port) do |http|
				http.request(req)
			end
			puts "Got response"
		rescue Timeout::Error
			raise "PIN authentication timed out"
		end

		# Verifier in response might be different?
		#certdata = JSON.parse(res.body)
		
		logincred = @talkservice.service.loginWithVerifierForCertificate(verifier)
		if logincred.authToken.nil?
			p logincred
			raise "Unknown error"
		else
			return logincred.authToken
		end
	end


	def get_rsa_login_key(username, password)
		logindata = JSON.parse(Net::HTTP.get_response(LINE_LOGIN_URI).body)
		session_key = logindata['session_key']
		rsa_key = logindata['rsa_key']

		ver, n, e = rsa_key.split(',')

		rsa = OpenSSL::PKey::RSA.new
		rsa.n = OpenSSL::BN.new(n, 16)
		rsa.e = OpenSSL::BN.new(e, 16)

		login = session_key.length.chr + session_key +
		        username.length.chr + username +
		        password.length.chr + password
		
		return rsa.public_encrypt(login).unpack('H*').first.upcase
	end

	def get_image_preview(id)
		imguri = URI.parse("#{LINE_OS_BASE_URL}/m/#{id}/preview")		
		req = Net::HTTP::Get.new(imguri.path)
		req['X-Line-Application'] = LINE_CLIENT
		req['X-Line-Access'] = @authtoken
		puts "Download preview #{imguri}"
		Net::HTTP.start(imguri.hostname, imguri.port) do |http|
			return http.request(req).body
		end
	end
	
	def get_image_obs(id)
		imguri = URI.parse(LINE_OBS_BASE_URL)	
		req = Net::HTTP::Get.new("/talk/m/download.nhn?ver=1.0&oid=#{id}")
		req['X-Line-Application'] = LINE_CLIENT
		req['X-Line-Access'] = @authtoken
		puts "Download obs #{imguri}"
		Net::HTTP.start(imguri.hostname, imguri.port) do |http|
			return http.request(req).body
		end
	end
	
	

	def get_groupids_joined
		return @talkservice.service.getGroupIdsJoined
	end

	def get_all_contactids
		return @talkservice.service.getAllContactIds
	end

	def get_contact(id)
		return @talkservice.service.getContact(id)
	end

	def get_contacts(id)
		return @talkservice.service.getContacts(id)
	end
	
	def get_group(id)
		return @talkservice.service.getGroup(id)
	end

	def get_groups(id)
		return @talkservice.service.getGroups(id)
	end

	def get_profile
		return @talkservice.service.getProfile
	end

	def get_last_rev
		return @talkservice.service.getLastOpRevision
	end
	
	def get_available_stickers
		return @shopservice.service.getActivePurchaseVersions(0,1000,"en","US")
	end

	def send_chat_checked(consumerid, messageid)
		get_new_service().service.sendChatChecked(0, consumerid, messageid)
		puts "sendchecked"
	end
	
	def get_new_service()
		service = ThriftService.new(LINE_TALK_URI, TalkService::Client)
		service.set_token(@authtoken)
		return service
	end
	

	def send_message(message)
		m = Message.new
		m.from = message.from
		m.to = message.to

		if (message.sticker != nil)
			m.contentType = ContentType::STICKER
			m.contentMetadata = {}
			m.contentMetadata['STKPKGID'] = message.sticker.set_id.to_s
			m.contentMetadata['STKVER'] = message.sticker.version.to_s
			m.contentMetadata['STKID'] = message.sticker.id.to_s
			m.contentMetadata['STKTXT'] = "[null]"

		elsif (message.image != nil)
			m.contentType = ContentType::IMAGE
		else
			m.contentType = ContentType::NONE
			m.text = message.text
		end
		
		response = get_new_service().service.sendMessage(0, m)
		if (response.nil? || response.id == "0")
			return nil
		end

		m.id = response.id
		
		if (message.image != nil)
			puts "Upload image for #{m.id}"
			upload(m.id, message.image.url)
		end
		
		m.createdTime = response.createdTime
		return m
	end
	
	def upload(id, filename)
		Thread.new do
			uploadservice = LineServiceUpload.new(@authtoken, LINE_CLIENT)
			uploadservice.upload(id, filename)
		end
	end

	def start_poll(revision, callback)
		Thread.new do
			begin
				result = @p4service.service.fetchOperations(revision, 50)
			rescue Timeout::Error
				result = []
			rescue Exception => e
				puts e
				puts e.backtrace
				result = []
			end

			callback.call(result)
		end
	end
end
