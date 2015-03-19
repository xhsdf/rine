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
	VPADDING = 2
	CORNER_SIZE = 5
	
	MESSAGE_VMARGIN = 7

	STICKER_SIZE = 92
	STICKER_COLUMNS = 5
	AVATAR_SIZE = 32
	TEXT_AREA_WIDTH = 480
	AVATAR_MARGIN = 5

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
			ltcorner.set_size_request(CORNER_SIZE, CORNER_SIZE)
			ltcorner.signal_connect('expose_event') do
				cr = ltcorner.window.create_cairo_context
				
				cr.rectangle(0, 0, ltcorner.allocation.width, ltcorner.allocation.height)
				cr.set_source_color(@bg_color)
				cr.fill
				
				cr.arc CORNER_SIZE * x, CORNER_SIZE * y, CORNER_SIZE, 0, 2 * Math::PI
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
							@menu.hide()
						elsif event.button == 3
							close()
						end
					end
				end
				@image_box.show_all()
			end
		end
	end


	class LineStickerPreviewMenu < Gtk::Window
		attr_reader :conversation, :sticker_previews, :sticker_menu_box, :sticker_sets
		
		def initialize()
			super()
			self.deletable = false
			self.type_hint = Gdk::Window::TYPE_HINT_DIALOG
			self.title = "Stickers"
			@sticker_sets = []
			@sticker_previews = []
			ebox = Gtk::EventBox.new
			self.add(ebox)
			ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			@sticker_menu_box = Gtk::VBox.new(false, 0)				
			
			swin = Gtk::ScrolledWindow.new
			swin.set_size_request(-1, 400)
			swin.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
			swin.vscrollbar.set_size_request(5, -1)			
			vport = Gtk::Viewport.new(nil, nil)
			vport.shadow_type = Gtk::SHADOW_NONE
			vport.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			vport.add(@sticker_menu_box)
			swin.add(vport)			
			ebox.add(swin)
			
			@sticker_menu_box.signal_connect("size-allocate") do |widget, allocation|
				self.set_size_request(allocation.width, -1)
			end
			
			self.signal_connect("button_press_event") do |widget, event|
				if event.button == 3
					hide()
				end
			end
		end
		
		
		def add_sticker_set(sticker_set)
			@sticker_sets << sticker_set
			sticker_preview = LineStickerPreview.new(sticker_set, self)
			sticker_previews << sticker_preview
			@sticker_menu_box.pack_start(sticker_preview, false, false, 0)
		end


		def set_conversation(conversation)
			@conversation = conversation
		end
	end
	

	class LineGuiMain
		attr_reader :management, :conversations, :tab_box, :chat_tab, :sticker_sets, :sticker_menu, :closed, :window
		
		def initialize(management)
			@management = management
			@conversations = {}
			@tab_box = Gtk::HBox.new(false, 0)
			@chat_tab = Gtk::VBox.new(false, 0)
			@sticker_sets = []
			@closed = false
			@sticker_menu = nil
			
			@window = Gtk::Window.new("rine alpha")
			#~ Gtk::Settings.default.gtk_im_module="ime"

			@window.signal_connect("destroy") do
				Gtk.main_quit()
				@closed = true
			end
			
			@window.signal_connect("notify::is-active") do
				if @window.active?
					conversations.values.select do |conv| conv.active end.each do |conv| conv.mark_last_read() end
					#~ puts "active!"
				else
					#~ puts "inactive!"
				end
			end
			
			@window.set_default_size(580, 600)
			
			main_box = Gtk::VBox.new(false, 0)
			@tab_box.set_size_request(-1, 15)
			tab_box_ebox = Gtk::EventBox.new()
			tab_box_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND))
			tab_box_ebox.add(@tab_box)
			
			swin = Gtk::ScrolledWindow.new
			swin.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_NEVER)
			swin.hscrollbar.set_size_request(-1, 5)
			swin.set_window_placement(Gtk::CORNER_BOTTOM_LEFT) # does not work
			vport = Gtk::Viewport.new(nil, nil)
			vport.shadow_type = Gtk::SHADOW_NONE
			vport.add(tab_box_ebox)
			swin.add(vport)
			
			
			
			main_box.pack_start(swin, false, false, 10)
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
				@tab_box.pack_start(@conversations[id].label, false, false)
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
			@sticker_menu.set_conversation(@conversations[id]) unless @sticker_menu.nil?
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
		end
		
		
		def show_sticker_menu()
			if @sticker_menu.nil? or @sticker_menu.destroyed?
				@sticker_menu = LineStickerPreviewMenu.new()
			end
			@sticker_sets.each do |sticker_set|
				@sticker_menu.add_sticker_set(sticker_set) unless (@sticker_menu.sticker_sets.include?(sticker_set))
			end
			@sticker_menu.show_all()
		end
		
		def show_file_chooser(conversation)
		filter = Gtk::FileFilter.new
		filter.add_pattern("*.jpg")
		filter.add_pattern("*.jpeg")
		filter.add_pattern("*.png")

		chooser = Gtk::FileChooserDialog.new("Select a file",
                                     nil,
                                     Gtk::FileChooser::ACTION_OPEN,
                                     nil,
                                     [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT], [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
		chooser.add_filter(filter)
		
		chooser.run do |response|
			if response == Gtk::Dialog::RESPONSE_ACCEPT
				image = LineMessage::Image.new(nil, chooser.filename, nil)
				send_message(conversation.id, nil, nil, image)
			end
		end
		
		chooser.destroy

		end
	end


	class LineGuiConversation
		attr_reader :id, :swin, :chat_box, :gui, :label, :messages, :box, :active, :ctrl, :input_textview, :scroll_to_bottom
		
		def initialize(id, gui)
			@id = id
			@gui = gui
			@chat_box = Gtk::VBox.new(false, 2)
			@active = false
			@messages = {}
			@ctrl = false
			@scroll_to_bottom = true
			
			chat_ebox = Gtk::EventBox.new()
			chat_ebox.add(@chat_box)
			chat_ebox.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_CHAT))
			
			@box = Gtk::VBox.new(false, 0)
			
			input_box = Gtk::HBox.new(false, 0)
			input_buttons_box = Gtk::HBox.new(false, 0)
			
			send_button = Gtk::Button.new("F")
			send_button_valignment = Gtk::Alignment.new(0, 1, 0, 0)
			send_button_valignment.add(send_button)
			input_buttons_box.pack_start(send_button_valignment, false, false)
			send_button.signal_connect('clicked') do |widget, event|
				@gui.show_file_chooser(self)
			end
			
			
			
			
			sticker_button = Gtk::Button.new(":)")
			sticker_button_valignment = Gtk::Alignment.new(0, 1, 0, 0)
			sticker_button_valignment.add(sticker_button)			
			input_buttons_box.pack_start(sticker_button_valignment, false, false)
			sticker_button.signal_connect('clicked') do |widget, event|
				@gui.show_sticker_menu()
				@gui.sticker_menu.set_conversation(self)
			end
			
			
			#~ send_button = Gtk::Button.new("Send")
			#~ send_button_valignment = Gtk::Alignment.new(0, 1, 0, 0)
			#~ send_button_valignment.add(send_button)
			#~ input_buttons_box.pack_start(send_button_valignment, false, false)
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
			
			input_box.pack_start(@input_textview_frame, true, true, 0)
			input_box.pack_start(input_buttons_ebox, false, false, 0)
						
			#~ send_button.signal_connect('clicked') do |widget, event|
				#~ send_buffer(@input_textview.buffer)
			#~ end
			
			@swin = Gtk::ScrolledWindow.new
			@swin.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
			@swin.vscrollbar.set_size_request(5, -1)
			vport = Gtk::Viewport.new(nil, nil)
			vport.shadow_type = Gtk::SHADOW_NONE
			vport.add(chat_ebox)
			@swin.add(vport)
			
			@swin.vadjustment.signal_connect('value-changed') do |wdt, evt|
				if @swin.vadjustment.value >= @swin.vadjustment.upper - @swin.vadjustment.page_size
					if @gui.window.active? and @active
						mark_last_read()
					end
					@scroll_to_bottom = true
				else
					@scroll_to_bottom = false
				end
			end
			
			chat_ebox.signal_connect("size-allocate") do
				if @scroll_to_bottom
						scroll_to_bottom()
				end
			end
			
			@label = ConversationLabel.new(@id, @gui)
			
			@box.pack_start(@swin, true, true, 0)
			@box.pack_start(input_box, false, false, 0)
			@box.set_size_request(0, -1)
			
			@box.show_all()
		end
		
		
		def mark_last_read()
			unless @messages.empty?
				@messages.to_a.last.last.mark_read()
			end
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
			conv_message = LineGuiConversationMessage.new(message, self)
			@messages[message.id] = conv_message
			message_box = conv_message
			message_box.show_all()

			halign = conv_message.user_is_sender ? Gtk::Alignment.new(1, 0, 0, 0) : Gtk::Alignment.new(0, 0, 0, 0)
			halign.add(message_box)
			
			halign.signal_connect("size-allocate") do
				conv_message.fit()
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
				mark_last_read()
				@input_textview.grab_focus
			end
		end
	end
	
	class LineGuiConversationMessage < Gtk::HBox
		attr_reader :id, :conversation, :gui, :message, :read_by, :infolabel, :marked, :user_is_sender, :label, :resizing
		
		def initialize(message, conversation)
			super(false, 2)
			@conversation = conversation
			@gui = @conversation.gui
			@id = message.id
			@message = message
			@read_by = []
			@marked = false
			@resizing = false
			@user_is_sender = message.from == @gui.management.get_own_user_id()
			sender_name = @gui.management.get_name(message.from)
			send_time = Time.at(message.timestamp).getlocal().strftime("%H:%M")
			@info_label = nil
		
			sender_info = "  [#{send_time}] #{sender_name}"
			if @user_is_sender
				sender_info = "[#{send_time}]   "
				@info_label = Gtk::Label.new()
				@info_label.set_markup("<small> </small>   ")
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

			halign_name = @user_is_sender ? Gtk::Alignment.new(1, 0, 0, 0) : Gtk::Alignment.new(0, 0, 0, 0)
			sender_info_label = Gtk::Label.new()
			sender_info_label.set_markup("<small>#{sender_info}</small>")
			halign_name.add(sender_info_label)
			message_container.pack_start(halign_name, false, false)
			
			if message.text != nil
				@label = Gtk::Label.new()
				@label.set_markup(get_markup(message.text))
				@label.wrap = true
				@label.selectable = true
				@label.wrap_mode = Pango::Layout::WRAP_WORD_CHAR
				ebox = LineLabelBox.new(@label, Gdk::Color.parse(@user_is_sender ? COLOR_TEXTBOX_SELF : COLOR_TEXTBOX), Gdk::Color.parse(BACKGROUND))
				
				@label.signal_connect('activate-link') do |label, url|
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

			if @user_is_sender
				self.pack_start(message_container, true, false)
				#~ self.pack_start(avatar_container, false, false)
			else
				self.pack_start(avatar_container, false, false, AVATAR_MARGIN)
				self.pack_start(message_container, true, false)
			end
			
			unless @info_label.nil?
				info_halign = Gtk::Alignment.new(1, 0, 0, 0)
				info_halign.add(@info_label)
				message_container.pack_start(info_halign, false, false)
			end			

			self.show_all()
		end
		
		def has_one_line()
			return @label.allocation.height < 20 # line height = 13 ?
		end
		
		
		def fit()
			unless @label.nil? or @resizing
				@resizing = true
				width = @gui.chat_tab.allocation.width - 70 - (2 * AVATAR_MARGIN)
				
				if @label.allocation.width > width
					@label.set_size_request(width, -1)
				elsif @label.allocation.width < width and not has_one_line()
					@label.set_size_request(@label.allocation.width + 10, -1)
				end
				@resizing = false
			end
		end
		
		
		def mark_read()
			unless @marked or @user_is_sender
				@marked = true
				@gui.management.mark_message_read(@conversation.id, @id)
			end
		end
		
		
		def add_read_by(user_id)
			unless read_by.include? user_id
				@read_by << user_id
				unless @info_label.nil? # TODO?: Gtk::Tooltips listing each reader
					if @conversation.id == user_id
						@info_label.set_markup("<small>read</small>   ")
					else
						@info_label.set_markup("<small>read by #{@read_by.size}</small>   ")
					end
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
			
			@label.set_markup("   <small>#{@gui.management.get_name(id) + "#{users.length == 0 ? "" : " (#{users.length})"}"}</small>   ")
			#~ @label.set_ellipsize(Pango::Layout::ELLIPSIZE_MIDDLE) 
			#~ @label.set_size_request(50, -1)
			
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
				self.parent.reorder_child(self, 0) unless self.parent.nil?
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
				self.parent.reorder_child(self, 0) unless self.parent.nil?
				self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_LABEL_HIGHLIGHT))
				@label.modify_fg(Gtk::StateType::NORMAL, Gdk::Color.parse(FOREGROUND_LABEL_HIGHLIGHT))
			else
				self.modify_bg(Gtk::StateType::NORMAL, Gdk::Color.parse(BACKGROUND_LABEL))
				@label.modify_fg(Gtk::StateType::NORMAL, Gdk::Color.parse(FOREGROUND_LABEL))
			end
		end
	end
end
