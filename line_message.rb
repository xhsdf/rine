module LineMessage
	class Message
		attr_reader :from, :to, :id, :timestamp, :text, :sticker, :image

		def initialize(from, to, id, timestamp, text = nil, sticker = nil, image = nil)
			@from, @to, @id, @timestamp, @text, @sticker, @image = from, to, id, timestamp, text, sticker, image
		end
	end


	class Image
		attr_reader :id, :url, :preview_url
		
		def initialize(id, url = nil, preview_url = nil)
			@id, @url, @preview_url = id, url, preview_url
		end
	end


	class StickerSet
		attr_reader :id, :name, :version, :stickers

		def initialize(id, name, version, stickers)
			@id, @name, @version, @stickers = id, name, version, stickers
		end
	end


	class Sticker
		attr_reader :set_id, :version, :id
		def initialize(set_id, version, id)
			@set_id, @version, @id = set_id, version, id
		end
	end
end