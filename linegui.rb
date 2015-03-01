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
	BACKGROUND_TEXTVIEW = "white"
	HPADDING = 10
	VPADDING = 5
	
	MESSAGE_VMARGIN = 7

	STICKER_SIZE = 92
	STICKER_COLUMNS = 5
	AVATAR_SIZE = 48
	TEXT_AREA_WIDTH = 480	

	class LineLabelBox < Gtk::HBox
		def initialize(label, box_color, bg_color, right = false)
			super(false, 0)
						
			#~ self.signal_connect("size-allocate") do |widget, allocation|
				#~ parent = widget
				#~ while (parent.class != Gtk::ScrolledWindow)
					#~ parent = parent.parent
				#~ end
				#~ parent = parent.parent.parent.parent.parent
				#~ puts parent.class
				#~ puts "#{parent.allocation.width}x#{parent.allocation.height}"
				#~ label.set_size_request(parent.allocation.width - 100, -1)
			#~ end
			
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
			mid.pack_start(label, true, true, VPADDING)
			mid_ebox = Gtk::EventBox.new()
			mid_ebox.modify_bg(Gtk::StateType::NORMAL, @box_color)
			mid_ebox.add(mid)

			self.pack_start(lcorner, false, false, 0)
			self.pack_start(mid_ebox, true, true, 0)
			self.pack_start(rcorner, false, false, 0)
		end
		
		
		def corner(x, y)
			ltcorner = Gtk::DrawingArea.new
			ltcorner.set_size_request(10,10)
			ltcorner.signal_connect('expose_event') do
				cr = ltcorner.window.create_cairo_context
				
				cr.rectangle(0, 0, ltcorner.allocation.width, ltcorner.allocation.height)
				cr.set_source_color(@bg_color)
				cr.fill
				
				cr.arc 10 * x, 10 * y, 10, 0, 2 * Math::PI
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
	
	
	class LineStickerPreview < Gtk::VBox
		attr_reader :sticker_set, :menu, :image_box, :expander
		
		def initialize(sticker_set, menu)
			super(false, 0)
			@sticker_set = sticker_set
			@menu = menu
			@image_box = Gtk::VBox.new(false, 0)
			
			@expander = Gtk::Expander.new(@sticker_set.name, true)
			@expander.add(@image_box)			
			
			expander.signal_connect("notify::expanded") do
				if expander.expanded?
					load_image_box()
				else
					#~ @expander.set_size_request(-1, 20)
				end
			end
			self.pack_start(@expander, false, false, 2)

			@expander.show_all()
			self.show_all()
		end
		
		
		def close()
			@expander.set_expanded(false)
		end
		
		
		def open()
			@expander.set_expanded(true)
		end
		
	
		def load_image_box()
			if @image_box.children.empty?
				sticker_set.stickers.each_with_index do |sticker, i|
					if i % STICKER_COLUMNS == 0
						@image_box.pack_start(Gtk::HBox.new(false, 0), false, false, 2)
					end
					sticker_image = Gtk::Image.new
					Thread.new do
						sticker_image.pixbuf = Gdk::Pixbuf.new(@menu.conversation.gui.management.get_sticker(sticker), STICKER_SIZE, STICKER_SIZE)
					end
					sticker_ebox = Gtk::EventBox.new
					sticker_ebox.add(sticker_image)
					sticker_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
					@image_box.children.last.pack_start(sticker_ebox, false, false, 2)
					
					sticker_ebox.signal_connect("button_press_event") do |widget, event|
						if event.button == 1
							@menu.conversation.gui.send_message(@menu.conversation.id, nil, sticker, nil)
							@menu.detach()
						elsif event.button == 3
							close()
						end
					end
				end
				@image_box.show_all()
			end
		end
	end


	class LineStickerPreviewMenu < Gtk::Frame
		attr_reader :conversation, :sticker_previews, :sticker_menu_box
		
		def initialize()
			super()
			@sticker_previews = []
			ebox = Gtk::EventBox.new
			self.add(ebox)
			ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			@sticker_menu_box = Gtk::VBox.new(false, 0)				
			
			@swin = Gtk::ScrolledWindow.new
			@swin.set_size_request(-1, 400)
			@swin.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
			@swin.vscrollbar.set_size_request(5, -1)
			vport = Gtk::Viewport.new(nil, nil)
			vport.shadow_type = Gtk::SHADOW_NONE
			vport.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			vport.add(@sticker_menu_box)
			@swin.add(vport)
			ebox.add(@swin)
			
			self.signal_connect("button_press_event") do |widget, event|
				if event.button == 3
					detach()
				end
			end
		end
		
		
		def add_sticker_set(sticker_set)
			sticker_preview = LineStickerPreview.new(sticker_set, self)
			sticker_previews << sticker_preview
			@sticker_menu_box.pack_start(sticker_preview, false, false, 0)
		end


		def set_conversation(conversation)
			@conversation = conversation
		end
		

		def detach()
			#~ sticker_previews.each do |sticker_preview|
					#~ sticker_preview.close()
			#~ end
			self.parent.remove(self) unless self.parent.nil?
		end
	end
	

	class LineGuiMain
		attr_reader :management, :conversations, :start_tab, :chat_tab, :sticker_sets, :sticker_menu, :closed, :window
		
		def initialize(management)
			@management = management
			@conversations = {}
			@start_tab = Gtk::VBox.new(false, 0)
			@chat_tab = Gtk::VBox.new(false, 0)
			@sticker_sets = []
			@closed = false
			@sticker_menu = LineStickerPreviewMenu.new()
			
			@window = Gtk::Window.new("rine alpha")
			#~ Gtk::Settings.default.gtk_im_module="ime"

			@window.signal_connect("destroy") do
				Gtk.main_quit()
				@closed = true
			end
			
			#~ @window.signal_connect("notify::is-active") do
				#~ if @window.active?
					#~ puts "active!"
				#~ else
					#~ puts "inactive!"
				#~ end
			#~ end
			
			
			@window.set_default_size(580, 600)
			
			main_box = Gtk::HBox.new(false, 0)
			start_tab_ebox = Gtk::EventBox.new()
			start_tab_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			start_tab_ebox.add(@start_tab)
			main_box.pack_start(start_tab_ebox, false, false, 10)
			main_box.pack_start(@chat_tab, true, true, 0)
			
			@window.add(main_box)
			
			@window.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			
			@window.show_all()
		end
		
		
		def add_user(id)
			return if @closed
			if @conversations[id] == nil
				@conversations[id] = LineGuiConversation.new(id, self)
			end
			if @conversations[id].label.parent == nil
				@start_tab.pack_start(@conversations[id].label, false, false)
			end
		end
		

		def add_message(message, log = false)
			return if @closed
			id = @management.get_conversation_id(message.from, message.to)
			
			add_user(id)
			@conversations[id].add_message(message, log)
			
			unless log
				if @conversations[id] != nil and not @conversations[id].active
					@conversations[id].label.highlight()
				end
			end
		end
		
		
		def run()
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
			@sticker_menu.add_sticker_set(sticker_set)
		end
	end


	class LineGuiConversation
		attr_reader :id, :swin, :chat_box, :gui, :label, :messages, :box, :active, :ctrl, :sticker_menu_box, :input_textview
		
		def initialize(id, gui)
			@id = id
			@gui = gui
			@chat_box = Gtk::VBox.new(false, 2)
			@active = false
			@messages = {}
			@ctrl = false
			@sticker_menu_box = Gtk::EventBox.new()
			
			chat_ebox = Gtk::EventBox.new()
			chat_ebox.add(@chat_box)
			chat_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_CHAT))
			
			@box = Gtk::VBox.new(false, 0)
			
			input_box = Gtk::HBox.new(false, 0)
			input_buttons_box = Gtk::HBox.new(false, 0)
				
			sticker_button = Gtk::Button.new("sticker")
			sticker_button_valignment = Gtk::Alignment.new(0, 1, 0, 0)
			sticker_button_valignment.add(sticker_button)			
			input_buttons_box.pack_start(sticker_button_valignment, false, false)
			sticker_button.signal_connect('clicked') do |widget, event|
				if @gui.sticker_menu.parent != @sticker_menu_box
					@gui.sticker_menu.detach()
					@sticker_menu_box.add(@gui.sticker_menu)
					@gui.sticker_menu.set_conversation(self)
				else
					@gui.sticker_menu.detach()
					@gui.sticker_menu.set_conversation(nil)
				end
				@sticker_menu_box.show_all()								
			end
			
			
			send_button = Gtk::Button.new("Send")
			send_button_valignment = Gtk::Alignment.new(0, 1, 0, 0)
			send_button_valignment.add(send_button)
			input_buttons_box.pack_start(send_button_valignment, false, false)
			input_buttons_ebox = Gtk::EventBox.new()
			input_buttons_ebox.add(input_buttons_box)
			input_buttons_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			
			@input_textview = Gtk::TextView.new
			@input_textview.set_size_request(0, -1)
			
			@input_textview_ebox = Gtk::EventBox.new()
			@input_textview_ebox.add(@input_textview)
			
			@input_textview_frame = Gtk::Frame.new
			@input_textview_frame.add(@input_textview_ebox)
			
			@input_textview.modify_base(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_TEXTVIEW))
			@input_textview_ebox.add_events(Gdk::Event::KEY_PRESS_MASK)
			
			# L_CTRL = 65507
			# R_CTRL = 65508
			@input_textview_ebox.signal_connect('key-press-event') do |widget, event|
				if event.keyval == 65507
					@ctrl = true
				end
			end
			
			@input_textview_ebox.signal_connect('key-release-event') do |widget, event|
				if event.keyval == 65507
					@ctrl = false
				end
			end			
			
			@input_textview.buffer.signal_connect('insert-text') do |widget, iter, text, len|
				if text == "\n" and not @ctrl
					send_buffer(widget)
				end
			end
			
			#~ @input_textview_ebox.signal_connect('key-press-event') do |wdt, evt|
				#~ if evt.keyval == 65508
					#~ send_buffer(@input_textview.buffer)
				#~ end
			#~ end
			
			input_box.pack_start(@input_textview_frame, true, true, 0)
			input_box.pack_start(input_buttons_ebox, false, false, 0)
						
			send_button.signal_connect('clicked') do |widget, event|
				send_buffer(@input_textview.buffer)
			end
			
			@swin = Gtk::ScrolledWindow.new
			@swin.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
			@swin.vscrollbar.set_size_request(5, -1)
			vport = Gtk::Viewport.new(nil, nil)
			vport.shadow_type = Gtk::SHADOW_NONE
			vport.add(chat_ebox)
			@swin.add(vport)
			
			@label = ConversationLabel.new(@id, @gui)
			
			@box.pack_start(@swin, true, true, 0)
			@box.pack_start(@sticker_menu_box, false, false, 0)
			@box.pack_start(input_box, false, false, 0)
			@box.set_size_request(0, -1)
			
			@box.show_all()
		end
		
		
		def send_buffer(buffer)
			return if buffer.text.nil? or buffer.text.strip.empty?
			@gui.send_message(@id, buffer.text.to_s, nil, nil)
			
			# thread to avoid "Invalid text buffer iterator"
			Thread.new do
				sleep 0.1
				buffer.text = ""
			end
		end

		
		def add_message(message, log = false)
			
			scroll_to_bottom = @swin.vadjustment.value >= @swin.vadjustment.upper - @swin.vadjustment.page_size
			
			scrollbar_pos = @swin.vadjustment.value
			conv_message = LineGuiConversationMessage.new(message, @gui)
			@messages[message.id] = conv_message
			message_box = conv_message
			message_box.show_all()
		
			user_is_sender = message.from == @gui.management.get_own_user_id()
			halign = user_is_sender ? Gtk::Alignment.new(1, 0, 0, 0) : Gtk::Alignment.new(0, 0, 0, 0)
			halign.add(message_box)
			
			halign.signal_connect("size-allocate") do
				if scroll_to_bottom or log or user_is_sender
						scroll_to_bottom()
				end
			end

			halign.show_all()
			@chat_box.pack_start(halign, false, false, MESSAGE_VMARGIN)
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
			if @active
				@input_textview.grab_focus
			end
		end
	end
	
	class LineGuiConversationMessage < Gtk::HBox
		attr_reader :id, :gui, :message, :read_by, :infolabel
		
		def initialize(message, gui)
			super(false, 2)
			@gui = gui
			@id = message.id
			@message = message
			@read_by = []
			user_is_sender = message.from == @gui.management.get_own_user_id()
			sender_name = @gui.management.get_name(message.from)
			send_time = Time.at(message.timestamp).getlocal().strftime("%H:%M")
			@info_label = nil
		
			sender_info = "  [#{send_time}] #{sender_name}"
			if user_is_sender
				sender_info = "[#{send_time}]   "
				@info_label = Gtk::Label.new
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
				text.set_markup(get_markup(message.text))
				text.wrap = true
				text.selectable = true
				text.wrap_mode = Pango::Layout::WRAP_WORD_CHAR
				ebox = LineLabelBox.new(text, Gdk::Color.parse(user_is_sender ? COLOR_TEXTBOX_SELF : COLOR_TEXTBOX), Gdk::Color.parse(BACKGROUND))
				
				text.signal_connect('activate-link') do |label, url|
					@gui.management.open_uri(url)
					true
				end
				
				message_container_hbox = Gtk::HBox.new(false, 2)
				message_container_hbox.pack_start(ebox, true, true, HPADDING)
				
				message_container.pack_start(message_container_hbox, true, true)
			end

			if message.sticker != nil
				sticker = Gtk::Image.new
				
				sticker_ebox = Gtk::EventBox.new()
				sticker_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND)) # TODO: transparent?
				sticker_ebox.add(sticker)
				
				sticker_ebox.signal_connect 'button-press-event' do |widget, event|
					if event.button == 1
						@gui.management.open_uri("https://store.line.me/stickershop/product/#{message.sticker.set_id}")
					end
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
					if event.button == 1
						Thread.new do
							@gui.management.open_uri(@gui.management.get_image(message))
						end
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
			
			unless @info_label.nil?
				info_halign = Gtk::Alignment.new(1, 0, 0, 0)
				info_halign.add(@info_label)
				message_container.pack_start(info_halign, false, false)
			end			

			self.show_all()
		end
		
		
		def add_read_by(user_id)
			unless read_by.include? user_id
				@read_by << user_id
				unless @info_label.nil? # TODO?: Gtk::Tooltips listing each reader
					@info_label.text = "read by #{@read_by.size}   "
					@info_label.show()
				end
				puts "Message #{@id} got read by #{@gui.management.get_name(user_id)}: #{@message.text}"
			end
		end
		
		
		def get_markup(text)
			message_string = text.encode(:xml => :text)
			message_string_with_urls = message_string
			message_string.scan(URI.regexp(['http', 'https'])) do |*matches|
				url = $&
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
