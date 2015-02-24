#!/usr/bin/ruby

module LineGui
	require 'gtk2'
	require 'pathname'
	require 'fileutils'
	require 'uri'

	$:.push('.')
	require 'line_message'

	COLOR_TEXTBOX = "lightblue"
	COLOR_TEXTBOX_SELF = "lightgreen"
	#~ BACKGROUND = "lightblue"
	BACKGROUND = "white"
	
	BACKGROUND_LABEL = "lightblue"
	FOREGROUND_LABEL = "black"
	BACKGROUND_LABEL_HIGHLIGHT = "lightgreen"
	FOREGROUND_LABEL_HIGHLIGHT = "black"
	BACKGROUND_LABEL_ACTIVE = "white"
	FOREGROUND_LABEL_ACTIVE = "black"
	
	BACKGROUND_CHAT = "white"
	BACKGROUND_LOG = "lightgrey"
	HPADDING = 10
	VPADDING = 10

	#~ STICKER_SIZE = 196
	AVATAR_SIZE = 48
	TEXT_AREA_WIDTH = 480	

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
	

	class LineGuiMain
		attr_reader :management, :conversations, :start_tab, :chat_tab, :sticker_sets, :sticker_menu
		
		def initialize(management)
			@management = management
			@conversations = {}
			@start_tab = Gtk::VBox.new(false, 0)
			@chat_tab = Gtk::VBox.new(false, 0)
			@sticker_sets = []
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
				if @conversations[id] != nil and not @conversations[id].active
					@conversations[id].label.highlight()
				end
			end
			#~ open_conversation(id) # TODO: @conversations[id].open
			#~ @conversations[id].scroll_to_bottom
		end
		
		
		def run()
			window = Gtk::Window.new
			#~ Gtk::Settings.default.gtk_im_module="ime"

			window.signal_connect("destroy") do
			  Gtk.main_quit
			end
			#~ window.border_width = 1
			window.set_default_size(520, 600)
			
			main_box = Gtk::HBox.new(false, 0)
			start_tab_ebox = Gtk::EventBox.new()
			start_tab_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			start_tab_ebox.add(@start_tab)
			main_box.pack_start(start_tab_ebox, false, false, 0)
			main_box.pack_start(@chat_tab, true, true, 0)
			window.add(main_box)
			
			window.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			
			window.show_all()

			Gtk.main()
		end
		
		
		def toggle_conversation(id)
			if @conversations[id] != nil
				if @conversations[id].is_open?
					close_conversation(id)
				else
					open_conversation(id)
				end
			end
		end
		
		
		def open_conversation(id)
			@conversations.keys.each do |key|
				close_conversation(key) unless key == id
			end
		
		
			@chat_tab.pack_start(@conversations[id].box, true, true)
			@conversations[id].set_active(true)
			@conversations[id].label.highlight(false)
			@conversations[id].label.active()
			# refresh new messages in inactive windows
			@conversations[id].swin.hide()
			@conversations[id].swin.show()
		end
		
		
		def close_conversation(id) # TODO
			if @conversations[id].box.parent == @chat_tab
				@chat_tab.remove(@conversations[id].box)
			end
			@conversations[id].set_active(false)
			@conversations[id].label.active(false)
		end
		
		
		def send_message(to, text, sticker, image)
			@management.send_message(to, text, sticker, image)
		end
		
		
		def add_sticker_set(sticker_set)
			@sticker_sets << sticker_set
			@sticker_menu = nil
		end
	end


	class LineGuiConversation
		attr_reader :id, :swin, :chat_box, :gui, :label, :new_messages, :box, :active
		
		def initialize(id, gui)
			@id = id
			@gui = gui
			@chat_box = Gtk::VBox.new(false, 2)
			@active = false
			@new_messages = []
			
			chat_ebox = Gtk::EventBox.new()
			chat_ebox.add(@chat_box)
			chat_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_CHAT))
			
			@box = Gtk::VBox.new(false, 0)
			
			input_box = Gtk::HBox.new(false, 0)
			input_buttons_box = Gtk::HBox.new(false, 0)
			
			sticker_button = Gtk::Button.new("sticker")
			input_buttons_box.add(sticker_button)
			sticker_button.signal_connect('clicked') do |widget, event|
				if @sticker_menu == nil
					@sticker_menu = Gtk::Menu.new
					@sticker_menu.reserve_toggle_size= false
					
					@gui.sticker_sets.each do |sticker_set|
						menu_item = Gtk::MenuItem.new(sticker_set.name)					
						@sticker_menu.append(menu_item)
						
						sub_menu = Gtk::Menu.new
						sub_menu.reserve_toggle_size= false
						
						sticker_set.stickers.each do |sticker|
							
							menu_item.set_submenu(sub_menu)
							
							sub_menu_item = Gtk::ImageMenuItem.new("")
							image = Gtk::Image.new
							Thread.new do image.pixbuf = Gdk::Pixbuf.new(gui.management.get_sticker(sticker), 48, 48) end
							sub_menu_item.image = image
							sub_menu_item.always_show_image = true
							
							sub_menu.append(sub_menu_item)
							
							sub_menu_item.signal_connect("activate") do |widget, event|
								@gui.send_message(@id, nil, sticker, nil)
							end
						
						end
						
					
					end
					
					@sticker_menu.show_all
				end
				
				Thread.new do @sticker_menu.popup(nil, nil, 0, 0) end.join				
			end
			
			
			send_button = Gtk::Button.new("Send")
			input_buttons_box.add(send_button)
			input_buttons_ebox = Gtk::EventBox.new()
			input_buttons_ebox.add(input_buttons_box)
			input_buttons_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			
			input_textview = Gtk::TextView.new
			input_textview.set_size_request(0, 25)
			input_box.pack_start(input_textview, true, true, 0)
			input_box.pack_start(input_buttons_ebox, false, false, 0)
						
			send_button.signal_connect('clicked') do |widget, event|
				text = input_textview.buffer.text
				sticker = nil
				image = nil
				
				if not text.nil? and text.empty?
					text = nil
				end
				unless text.nil? and sticker.nil? and image.nil?
					@gui.send_message(@id, text, sticker, image)
				end
				
				input_textview.buffer.delete(input_textview.buffer.start_iter, input_textview.buffer.end_iter)
			end
			
			@swin = Gtk::ScrolledWindow.new
			@swin.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
			@swin.vscrollbar.set_size_request(5, -1)
			vport = Gtk::Viewport.new(nil, nil)
			vport.shadow_type = Gtk::SHADOW_NONE
			vport.add(chat_ebox)
			@swin.add(vport)
			
			#~ @swin.vscrollbar.get_internal_child.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			#~ @swin.vscrollbar.signal_connect("value-changed") do |widget, event|
				#~ if @swin.vadjustment.value >= @swin.vadjustment.upper - @swin.vadjustment.page_size
					#~ @swin.vscrollbar.set_child_visible(false)
				#~ else
					#~ @swin.vscrollbar.set_child_visible(true)
				#~ end
			#~ end			
			
			@label = ConversationLabel.new(@id, @gui)
			
			@box.pack_start(@swin, true, true, 0)
			@box.pack_start(input_box, false, false, 0)
			
			@box.show_all()
		end

		
		def add_message(message, log = false)
			scroll_to_bottom = @swin.vadjustment.value >= @swin.vadjustment.upper - @swin.vadjustment.page_size
			
			scrollbar_pos = @swin.vadjustment.value
			message_box = LineGuiConversationMessage.new(message, @gui)
			message_box.show_all()
		
			user_is_sender = message.from == @gui.management.get_own_user_id()
			halign = user_is_sender ? Gtk::Alignment.new(1, 0, 0, 0) : Gtk::Alignment.new(0, 0, 0, 0)
			halign.add(message_box)
			
			halign.signal_connect("size-allocate") do
				if scroll_to_bottom or log
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

		
		def is_open?()
			return @box.parent != nil
		end
		
		
		def set_active(active)
			@active = active		
		end
	end
	
	class LineGuiConversationMessage < Gtk::HBox
		attr_reader :id, :gui
		
		def initialize(message, gui)
			super(false, 2)
			@gui = gui
			@id = message.id
			user_is_sender = message.from == @gui.management.get_own_user_id()
			sender_name = @gui.management.get_name(message.from)
			send_time = Time.at(message.timestamp).getlocal().strftime("%H:%M")
			sender_info = "  [#{send_time}] #{sender_name}"
			if user_is_sender
				sender_info = "[#{send_time}]  "
			end
		
			box = Gtk::VBox.new(false, 2)
			avatar = Gtk::Image.new
			Thread.new do
				avatar.pixbuf = Gdk::Pixbuf.new(@gui.management.get_avatar(message.from), AVATAR_SIZE, AVATAR_SIZE)
			end
			
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
				
				text.signal_connect('activate-link') do |label, url|
					@gui.management.open_uri(url)
					true
				end

				text.set_markup(get_markup(message.text))
				text.wrap = true
				text.selectable = true
				text.wrap_mode = Pango::Layout::WRAP_WORD_CHAR
				message_container_hbox = Gtk::HBox.new(false, 2)
				message_container_hbox.pack_start(ebox, true, true, HPADDING)
				
				message_container.pack_start(message_container_hbox, true, true)
			end
			
			if message.sticker != nil
				sticker = Gtk::Image.new
				
				sticker_ebox = Gtk::EventBox.new()
				sticker_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND)) # TODO: transparent?
				sticker_ebox.add(sticker)
				
				sticker_ebox.signal_connect 'button-press-event' do |widget, event| # TODO: left button only
					@gui.management.open_uri("https://store.line.me/stickershop/product/#{message.sticker.set_id}")
				end
				
				Thread.new do
					sticker.pixbuf = Gdk::Pixbuf.new(@gui.management.get_sticker(message.sticker))
				end
				message_container.add(sticker_ebox)
			end
			
			if message.image != nil
				image = Gtk::Image.new
				
				image_ebox = Gtk::EventBox.new()
				image_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND)) # TODO: transparent?
				image_ebox.add(image)
				
				image_ebox.signal_connect 'button-press-event' do |widget, event| # TODO: left button only
					Thread.new do
						@gui.management.open_uri(@gui.management.get_image(message))
					end
				end
				
				Thread.new do
					image.pixbuf = Gdk::Pixbuf.new(@gui.management.get_image(message, true))
				end
				message_container.add(image_ebox)
			end
			
			
			if user_is_sender
				self.pack_start(message_container, true, false)
				#~ self.pack_start(avatar_container, false, false)
			else
				self.pack_start(avatar_container, false, false)
				self.pack_start(message_container, true, false)
			end
			

			self.show_all()
		end
		
		
		def get_markup(text)
			message_string = text.encode(:xml => :text)
			message_string_with_urls = message_string
			message_string.scan(URI.regexp(['http', 'https'])) do |url_match|
				url = url_match.join
				url.sub!(/http(?!:\/\/)/, 'http://')
				message_string_with_urls = message_string_with_urls.gsub(url, "<a href=\"#{url}\">#{url}</a>")
			end
			return message_string_with_urls
		end
	end
	
	
	class ConversationLabel < Gtk::EventBox
		attr_reader :id, :gui, :highlighted, :label
		
		def initialize(id, gui)
			super()
			@id = id
			@gui = gui
			@highlighted = false
			users = @gui.management.get_users(id)
			self.set_size_request(-1, 25)
			
			@label = Gtk::Label.new()
			
			@label.set_label(@gui.management.get_name(id) + "#{users.length == 0 ? "" : " (#{users.length})"}")
			
			self.signal_connect('button-press-event') do |widget, event|
				@gui.toggle_conversation(@id)
			end
			self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_LABEL))
			@label.modify_fg(Gtk::StateType::NORMAL, Gdk::Color.parse(FOREGROUND_LABEL))

			self.add(@label)
			self.show_all()
		end
		
		
		def active(active = true)
			if active
				self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_LABEL_ACTIVE))
				@label.modify_fg(Gtk::StateType::NORMAL, Gdk::Color.parse(FOREGROUND_LABEL_ACTIVE))
			else
				#~ self.modify_bg(Gtk::StateType::NORMAL, Gtk::Widget.default_style.bg(Gtk::StateType::NORMAL))
				self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_LABEL))
				@label.modify_fg(Gtk::StateType::NORMAL, Gdk::Color.parse(FOREGROUND_LABEL))
			end
		end
		
		
		def highlight(highlight = true)
			@highlighted = highlight
			if highlight
				self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_LABEL_HIGHLIGHT))
				@label.modify_fg(Gtk::StateType::NORMAL, Gdk::Color.parse(FOREGROUND_LABEL_HIGHLIGHT))
			else
				self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_LABEL))
				@label.modify_fg(Gtk::StateType::NORMAL, Gdk::Color.parse(FOREGROUND_LABEL))
			end
		end
	end
end
