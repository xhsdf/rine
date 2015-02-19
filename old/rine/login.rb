#!/usr/bin/env ruby

$:.push('gen-rb')
require 'thrift'
require 'talk_service'
require 'shop_service'
require 'net/http'
require 'json'
require 'openssl'


class LineService

	LINE_CLIENT = "DESKTOPWIN\t3.7.0\tWINDOWS\t5.1.2600-XP-x64"
	LINE_BASE_URL = "http://gd2.line.naver.jp/"
	LINE_TALK_URI = URI.parse(LINE_BASE_URL + "api/v4/TalkService.do")
	LINE_CERT_URI = URI.parse(LINE_BASE_URL + "Q")
	LINE_P4_URI = URI.parse(LINE_BASE_URL + "P4")
	LINE_SHOP_URI = URI.parse(LINE_BASE_URL + "SHOP4")
	LINE_LOGIN_URI = URI.parse(LINE_BASE_URL + "authct/v1/keys/line")

	class ThriftService
		attr_reader :service
		def initialize(uri, service)
			@transport = Thrift::HTTPClientTransport.new(uri)
			@transport.add_headers('X-Line-Application' => LINE_CLIENT)
			protocol = Thrift::CompactProtocol.new(@transport)
			@service = service.new(protocol)
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
end


x = LineService.new
puts x.login("xhsdf.misc@googlemail.com", "password", nil)
