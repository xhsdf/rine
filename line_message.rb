#!/usr/bin/ruby

module LineMessage
	class Message
		attr_reader :from, :to, :id, :timestamp, :text, :sticker, :image

		def initialize(from, to, id, timestamp, text = nil, sticker = nil, image = nil)
			@from, @to, @id, @timestamp, @text, @sticker, @image = from, to, id, timestamp, text, sticker, image
		end
		
		
		def to_xml()
			return "<message id=\"#{@id}\" from=\"#{@from}\" to=\"#{@to}\" timestamp=\"#{@timestamp}\">#{sticker.nil? ? "" : sticker.to_xml}#{image.nil? ? "" : image.to_xml}#{@text.nil? ? "" : "<text>#{@text.encode(:xml => :text)}</text>"}</message>"
		end
	end


	class Image
		attr_reader :id, :url, :preview_url
		
		def initialize(id, url = nil, preview_url = nil)
			@id, @url, @preview_url = id, url, preview_url
		end
		
		
		def to_xml()
			return "<image id=\"#{@id}\"#{@url.nil? ? "" : " url=\"#{@url}\""}#{@preview_url.nil? ? "" : " url=\"#{@preview_url}\""}/>"
		end
	end


	class StickerSet
		attr_reader :id, :version, :stickers
		def initialize(id, version, stickers)
			@id, @version, @stickers = id, version, stickers
		end
	end


	class Sticker
		attr_reader :set_id, :version, :id
		def initialize(set_id, version, id)
			@set_id, @version, @id = set_id, version, id
		end
		
		
		def to_xml()
			return "<sticker set_id=\"#{@set_id}\" version=\"#{@version}\" id=\"#{@id}\"/>"
		end
	end
end