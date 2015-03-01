module LineMessage
	class Message
		attr_reader :from, :to, :id, :timestamp, :text, :sticker, :image, :revision

		def initialize(from, to, id, timestamp, text = nil, sticker = nil, image = nil, revision = nil)
			@from, @to, @id, @timestamp, @text, @sticker, @image,  @revision = from, to, id, timestamp, text, sticker, image, revision
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