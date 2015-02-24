#!/usr/bin/ruby

module LineLogger
	require 'pathname'
	require 'fileutils'
	require "rexml/document"
	
	$:.push('.')
	require 'linegui'
	require 'line_message'

	class Logger
		attr_reader :management, :folder
		
		def initialize(management, folder = ".")
			@management = management
			@folder = folder
		end


		def add_message(message)
			id = nil
			if message.to == @management.get_own_user_id()
				id = message.from
			else
				id = message.to
			end
			File.open("#{folder}/#{id}.log", 'a') do |f| f.puts(message_to_xml(message)) end
		end
		
		
		def get_messages(id, limit = 25)
			messages = []
			begin
				File.readlines("#{folder}/#{id}.log").reverse.each_with_index do |line, index|
					if limit == nil or index < limit
						doc = REXML::Document.new(line)
						text = doc.root.elements["text"]
						text = text.text.to_s unless text.nil?
						from = doc.root.attributes["from"]
						to = doc.root.attributes["to"]
						id = doc.root.attributes["id"]
						timestamp = doc.root.attributes["timestamp"]
						sticker = doc.root.elements["sticker"]
						if sticker != nil
							sticker = LineMessage::Sticker.new(sticker.attributes["set_id"], sticker.attributes["version"], sticker.attributes["id"])
						end
						image = doc.root.elements["image"]
						if image != nil
							image = LineMessage::Image.new(image.attributes["id"], image.attributes["url"], image.attributes["preview_url"])
						end
						
						messages << LineMessage::Message.new(from, to, id, timestamp.to_i, text.nil? ? text : text.gsub("[\\n]", "\n"), sticker, image)
						
					end
				end
			rescue Errno::ENOENT
			end
				return messages.reverse
		end
	
	
		def message_to_xml(message)
			return "<message id=\"#{message.id}\" from=\"#{message.from}\" to=\"#{message.to}\" timestamp=\"#{message.timestamp}\">#{message.sticker.nil? ? "" : sticker_to_xml(message.sticker)}#{message.image.nil? ? "" : image_to_xml(message.image)}#{message.text.nil? ? "" : "<text>#{message.text.encode(:xml => :text).gsub("\n", "[\\n]")}</text>"}</message>"
		end
		
		
		def sticker_to_xml(sticker)
			return "<sticker set_id=\"#{sticker.set_id}\" version=\"#{sticker.version}\" id=\"#{sticker.id}\"/>"
		end
			
			
		def image_to_xml(image)
			return "<image id=\"#{image.id}\"#{image.url.nil? ? "" : " url=\"#{image.url}\""}#{image.preview_url.nil? ? "" : " url=\"#{image.preview_url}\""}/>"
		end
	end
end