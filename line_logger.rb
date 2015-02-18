#!/usr/bin/ruby


require './linegui.rb'

module LineLogger
	require 'pathname'
	require 'fileutils'
	require 'uri'

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
			sticker = ""
			image = ""
			if message.sticker != nil
				sticker = "#{message.sticker.set_id}-#{message.sticker.version}-#{message.sticker.id}"
			end
			if message.image != nil
				image = message.image.id
			end
			
			File.open("#{folder}/#{id}.log", 'a') do |f| f.puts("#{message.id}|#{message.from}|#{message.to}|#{message.timestamp}|#{sticker}|#{image}|#{message.text}".gsub("\n", "\\n").gsub("\r", "")) end
		end
		
		
		def get_messages(id, limit = 25)
			messages = []
			begin
				File.readlines("#{folder}/#{id}.log").reverse.each_with_index do |line, index|
					if limit == nil or index < limit
						line_parts = line.split('|')
						id = line_parts.shift.to_i
						to = line_parts.shift.to_i
						from = line_parts.shift.to_i
						timestamp = line_parts.shift.to_i
						sticker = line_parts.shift.split('-')
						image = line_parts.shift
						image.empty? ? nil : image.to_i
						text = line_parts.join('|').strip
						
						messages << LineGui::LineMessage.new(to, from, id, timestamp, text.empty? ? nil : text, sticker.empty? ? nil : LineGui::LineSticker.new(sticker[0].to_i, sticker[1].to_i, sticker[2].to_i), image.empty? ? nil : LineGui::LineImage.new(image))
					end
				end
			rescue Errno::ENOENT
			end
				return messages.reverse
		end
	end

end