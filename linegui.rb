#!/usr/bin/ruby


module LineGui
	require 'gtk2'
	require 'pathname'
	require 'fileutils'
	require 'uri'


	COLOR_TEXTBOX = "white"
	COLOR_TEXTBOX_SELF = "lightgreen"
	BACKGROUND = "lightblue"
	BACKGROUND_LOG = "lightgrey"
	HPADDING = 10
	VPADDING = 10

	STICKER_SIZE = 196
	AVATAR_SIZE = 48

	TEXT_AREA_WIDTH = 480

	class LineMessage
		attr_reader :from, :to, :id, :timestamp, :text, :sticker, :image

		def initialize(from, to, id, timestamp, text = nil, sticker = nil, image = nil)
			@from, @to, @id, @timestamp, @text, @sticker, @image = from, to, id, timestamp, text, sticker, image
		end
	end

	class LineLabelBox < Gtk::HBox
		def initialize(label, box_color, bg_color, right = false)
			super(false, 0)
			@box_color, @bg_color = box_color, bg_color
			lcorner = Gtk::VBox.new(false, 0)
			lcorner.pack_start(corner(1, 1), false, false, 0)
			lcorner.pack_start(bg(), true, true, 0)
			lcorner.pack_start(corner(1, 0), false, false, 0)
			rcorner = Gtk::VBox.new(false, 0)
			rcorner.pack_start(corner(0, 1), false, false, 0)
			rcorner.pack_start(bg(), true, true, 0)
			rcorner.pack_start(corner(0, 0), false, false, 0)
			
			mid = Gtk::VBox.new(false, 0)
			mid.pack_start(label, false, false, VPADDING)
			mid_ebox = Gtk::EventBox.new()
			mid_ebox.modify_bg(Gtk::StateType::NORMAL, @box_color)
			mid_ebox.add(mid)			
			if right
				self.pack_end(rcorner, false, false, 0)			
				self.pack_end(mid_ebox, false, false, 0)			
				self.pack_end(lcorner, false, false, 0)
			else
				self.pack_start(lcorner, false, false, 0)			
				self.pack_start(mid_ebox, false, false, 0)			
				self.pack_start(rcorner, false, false, 0)
			end
			
			valign_avatar =  Gtk::Alignment.new(0, 0, 0, 0)
		end
		
		
		def corner(x, y)
			ltcorner = Gtk::DrawingArea.new
			ltcorner.set_size_request(10,10)
			ltcorner.signal_connect('expose_event') do
				cr = ltcorner.window.create_cairo_context
				
				cr.rectangle(0, 0, ltcorner.allocation.width, ltcorner.allocation.height)
				cr.set_source_color(@bg_color)
				cr.fill
				
				cr.arc 10*x, 10*y, 10, 0, 2*Math::PI
				cr.set_source_color(@box_color)
				cr.fill			
			end
			return ltcorner
		end
		

		def bg()
			bgbox = Gtk::EventBox.new
			bgbox.modify_bg(Gtk::StateType::NORMAL, @box_color)
			return bgbox
		end
	end


	class LineImage
		attr_reader :id
		def initialize(id)
			@id = id
		end
	end


	class LineSticker
		attr_reader :set_id, :version, :id
		def initialize(set_id, version, id)
			@set_id, @version, @id = set_id, version, id
		end
	end
	

	class LineGuiMain
		attr_reader :management, :notebook, :conversations, :start_tab
		
		def initialize(management)
			@management = management
			@notebook = Gtk::Notebook.new
			@conversations = {}
			@start_tab = Gtk::VBox.new(false, 0)
			
			notebook.append_page(@start_tab, Gtk::Label.new("start"))
		end
		
		
		def add_user(id)			
			if @conversations[id] == nil
				@conversations[id] = LineGuiConversation.new(id, self)
			end
			if @conversations[id].label.parent == nil
				@start_tab.pack_start(@conversations[id].label, false, false)
			end
		end
		

		def add_message(message, log = false)
			id = nil
			if message.to == @management.get_own_user_id()
				id = message.from
			else
				id = message.to
			end
			
			add_user(id)
			@conversations[id].add_message(message, log)
			
			unless log
				if @conversations[id] != nil
					@conversations[id].label.highlight()
				end				
			end
			open_conversation(id) # TODO: @conversations[id].open
			#~ @conversations[id].scroll_to_bottom
			
		end
		
		def run()
			window = Gtk::Window.new
			#~ Gtk::Settings.default.gtk_im_module="ime"

			window.signal_connect("destroy") do
			  Gtk.main_quit
			end
			window.border_width = 1		
			
			window.set_default_size(800, 600)
			
			window.add(@notebook)
			
			window.show_all

			Gtk.main	
		end
		
		
		def open_conversation(id, background = true)
			unless @conversations[id] == nil or @conversations[id].swin.parent != nil
				@notebook.append_page(@conversations[id].swin, Gtk::Label.new(management.get_name(id)))
			end
			
			@notebook.set_page(@notebook.page_num(@conversations[id].swin)) unless background
		end
		
		
		def close_conversation(user_or_group_id, messages) # TODO
			conversation = @conversations[user_or_group_id]
			notebook.remove(convo.swin)
			@conversations[user_or_group_id] = nil
		end	
	end


	class LineGuiConversation
		attr_reader :id, :swin, :chat_box, :gui, :label, :new_messages
		
		def initialize(id, gui)
			@id = id
			@gui = gui
			@chat_box = Gtk::VBox.new(false, 2)
			@new_messages = []
			
			chat_ebox = Gtk::EventBox.new()
			chat_ebox.add(@chat_box)
			chat_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			
			@swin = Gtk::ScrolledWindow.new
			@swin.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
			vport = Gtk::Viewport.new(nil, nil)
			vport.shadow_type = Gtk::SHADOW_NONE
			vport.add(chat_ebox)
			@swin.add(vport)
			@swin.show_all()
			
			@label = ConversationLabel.new(@id, @gui)
			
			#~ @swin.signal_connect('expose_event') do # TODO ????
				#~ @label.highlight(false)
			#~ end
			
			@swin.show_all()
			
		
		end	
		
		def add_message(message, log = false)
			scroll_to_bottom = @swin.vadjustment.value >= @swin.vadjustment.upper - @swin.vadjustment.page_size
			
			scrollbar_pos = @swin.vadjustment.value
				message_box = LineGuiConversationMessage.new(message, @gui)
				message_box.show_all
			
				user_is_sender = message.from == @gui.management.get_own_user_id()
				halign = user_is_sender ? Gtk::Alignment.new(1, 0, 0, 0) : Gtk::Alignment.new(0, 0, 0, 0)
				halign.add(message_box)
				
				halign.signal_connect("size-allocate") do
					if scroll_to_bottom
							scroll_to_bottom()
					end
				end
						
				halign.show_all()
				@chat_box.pack_start(halign, false, false, 20)
		end
		
		def scroll_to_bottom()						
			adj = @swin.vadjustment
			adj.set_value(adj.upper - adj.page_size)
		end
	end
	
	class LineGuiConversationMessage < Gtk::HBox
		attr_reader :id, :gui, :highlighted
		
		def initialize(message, gui)
			super(false, 2)
			@gui = gui
			@id = message.id
			
			user_is_sender = message.from == @gui.management.get_own_user_id()
			
			sender_name = @gui.management.get_name(message.from)
			send_time = Time.at(message.timestamp).getlocal().strftime("%H:%M")
			sender_info = "  [#{send_time}] #{sender_name}"
			if user_is_sender
				sender_info = "#{sender_name} [#{send_time}]  "			
			end
		
			box = Gtk::VBox.new(false, 2)
			avatar = Gtk::Image.new
			avatar.pixbuf = Gdk::Pixbuf.new(@gui.management.get_avatar(message.from), AVATAR_SIZE, AVATAR_SIZE)			
			
			avatar_container = Gtk::VBox.new(false, 2)
			valign_avatar =  Gtk::Alignment.new(0, 0, 0, 0)
			valign_avatar.add(avatar)
			avatar_container.pack_end(valign_avatar)
			
			message_container = Gtk::VBox.new(false, 2)
			halign_name = user_is_sender ? Gtk::Alignment.new(1, 0, 0, 0) : Gtk::Alignment.new(0, 0, 0, 0)
			halign_name.add(Gtk::Label.new(sender_info))
			message_container.pack_start(halign_name, false, false)
					
			if message.text != nil				
				text = Gtk::Label.new()				
				
				ebox = LineLabelBox.new(text, Gdk::Color.parse(user_is_sender ? COLOR_TEXTBOX_SELF : COLOR_TEXTBOX), Gdk::Color.parse(BACKGROUND), user_is_sender)
				
				message_string = message.text.encode(:xml => :text)
				message_string_with_urls = message_string
				message_string.scan(URI.regexp) do |url_match|
					url = url_match.join
					url.sub!(/http(?!:\/\/)/, 'http://')
					message_string_with_urls = message_string_with_urls.gsub(url, "<a href=\"#{url}\">#{url}</a>")
				end
				
				text.signal_connect('activate-link') do |label, url|
					@gui.management.open_url(url)
					true
				end
								
				text.set_markup(message_string_with_urls)
				#~ text.set_markup("<span background = 'black' foreground='white'>#{message.text}</span>")
				text.wrap = true
				text.selectable = true
				#~ text.set_size_request(TEXT_AREA_WIDTH, -1)
				text.wrap_mode = Pango::Layout::WRAP_WORD_CHAR
				
				#~ message_ebox.shadow_type = Gtk::ShadowType::ETCHED_OUT
				#~ message_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(user_is_sender ? COLOR_TEXTBOX_SELF : COLOR_TEXTBOX))
				
				#~ message_ebox = Gtk::EventBox.new()
				#~ message_ebox.add(text)
				#~ message_container.add(message_ebox)
				message_container_hbox = Gtk::HBox.new(false, 2)
				message_container_hbox.pack_start(ebox, true, true, HPADDING)
				
				message_container.pack_start(message_container_hbox, true, true)
			end
			if message.sticker != nil
				sticker = Gtk::Image.new
				sticker.pixbuf = Gdk::Pixbuf.new(@gui.management.get_sticker(message.sticker.set_id, message.sticker.version, message.sticker.id), STICKER_SIZE, STICKER_SIZE)
				message_container.add(sticker)		
			end
			
			
			if user_is_sender
				self.pack_start(message_container, true, false)
				self.pack_start(avatar_container, false, false)
			else
				self.pack_start(avatar_container, false, false)
				self.pack_start(message_container, true, false)
			end
			

			self.show_all()
		end	
	end
	
	
	class ConversationLabel < Gtk::Button
		attr_reader :id, :gui, :highlighted
		
		def initialize(id, gui)
			super()
			@id = id
			@gui = gui
			@highlighted = false
			users = @gui.management.get_users(id)
			
			self.set_label(@gui.management.get_name(id) + "#{users.length == 0 ? "" : " (#{users.length})"}")
			
			self.signal_connect('clicked') do |widget, event|
				@gui.open_conversation(@id, false)
			end
			
			self.show()
		end
		
		
		def highlight(highlight = true)
			return if highlight == @highlighted
			@highlighted = highlight
			if highlight
				self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse("lightgreen"))
			else
				self.modify_bg(Gtk::StateType::NORMAL, Gtk::Widget.default_style.bg(Gtk::StateType::NORMAL))
			end
		end
	end
end