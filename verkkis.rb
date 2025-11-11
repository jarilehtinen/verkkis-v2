require 'curses'
require 'io/console'
require 'launchy'
require 'json'
require_relative 'lib/config'
require_relative 'lib/data'
require_relative 'lib/favorites'
require_relative 'lib/searches'
require_relative 'lib/ui'
require_relative 'lib/manufacturers'
require_relative 'lib/productinfo'
require_relative 'lib/fuzzy_search'

def main
    ENV['ESCDELAY'] = '25'
    # Activate alternate screen
    print "\e[?1049h"

    # Initialize curses
    Curses.init_screen
    Curses.curs_set(0) # Hide cursor
    Curses.start_color
    Curses.init_pair(1, Curses::COLOR_WHITE, Curses::COLOR_BLACK) # Basic
    Curses.init_pair(2, Curses::COLOR_BLACK, Curses::COLOR_WHITE) # Highlighted
    Curses.init_pair(3, Curses::COLOR_YELLOW, Curses::COLOR_BLACK) # Price
    Curses.init_pair(4, Curses::COLOR_BLACK, Curses::COLOR_YELLOW) # Highlighted price

    Curses.init_color(8, 1000, 1000, 1000) # Bright white
    Curses.init_pair(5, 8, Curses::COLOR_BLACK)

    Curses.init_pair(6, Curses::COLOR_MAGENTA, Curses::COLOR_BLACK) # Basic
    Curses.init_pair(7, Curses::COLOR_RED, Curses::COLOR_BLACK)
    Curses.init_pair(8, Curses::COLOR_RED, Curses::COLOR_WHITE)
    Curses.init_pair(9, Curses::COLOR_GREEN, Curses::COLOR_BLACK) # Basic
    Curses.init_pair(10, Curses::COLOR_GREEN, Curses::COLOR_WHITE) # Basic
    Curses.init_pair(11, Curses::COLOR_CYAN, Curses::COLOR_BLACK) # Help key highlight

    # Enable keypad mode for the main window
    Curses.stdscr.keypad(true)
    Curses.noecho

    begin
        data = Verkkis::Data.new
        favorites = Verkkis::Favorites.new
        ui = Verkkis::UI.new

        # Variables
        search_term = ""
        current_product = 0
        selection_position = 0
        start_row = 0
        show = "added"
        order = "desc"
        manufacturer_filter = nil
        manufacturer_prev_state = nil
        resize_pending = false
        pending_key = nil
        favorite_delete_keys = [127, 8]
        favorite_delete_keys << Curses::Key::BACKSPACE if defined?(Curses::Key::BACKSPACE)
        favorite_delete_keys << Curses::Key::DC if defined?(Curses::Key::DC)

        # Lines and cols
        Config.max_lines = Curses.lines
        Config.max_cols = Curses.cols

        # Load products
        products = data.get_products

        # Store products for resetting
        original_products = products.dup

        select_manufacturer = lambda do |fallback_title, capture_previous: false|
            fallback_title = fallback_title.to_s

            if capture_previous && manufacturer_prev_state.nil?
                stored_title = fallback_title.empty? ? ui.current_title.to_s : fallback_title
                stored_title = "Uusimmat tuotteet" if stored_title.empty?

                manufacturer_prev_state = {
                    products: products.dup,
                    show: show,
                    order: order,
                    search_term: search_term,
                    start_row: start_row,
                    selection_position: selection_position,
                    current_product: current_product,
                    title: stored_title
                }
            end

            manufacturers = Verkkis::Manufacturers.new
            selected_manufacturer = manufacturers.list(ui, original_products)

            title_to_draw = nil

            if selected_manufacturer
                manufacturer_filter = selected_manufacturer
                products = original_products.select do |product|
                    name = product['name']
                    next false unless name
                    name.split(/\s/).first == selected_manufacturer
                end

                title_to_draw = "Valmistaja: #{selected_manufacturer}"

                show = "manufacturer"
                start_row = 0
                selection_position = 0
                current_product = 0
            else
                if manufacturer_prev_state
                    stored_products = manufacturer_prev_state[:products] || []
                    products = stored_products.dup
                    show = manufacturer_prev_state[:show]
                    order = manufacturer_prev_state[:order]
                    search_term = manufacturer_prev_state[:search_term]
                    start_row = manufacturer_prev_state[:start_row]
                    selection_position = manufacturer_prev_state[:selection_position]
                    current_product = manufacturer_prev_state[:current_product]
                    title_to_draw = manufacturer_prev_state[:title]
                    manufacturer_prev_state = nil
                    manufacturer_filter = nil
                else
                    title_to_draw = fallback_title.empty? ? (manufacturer_filter ? "Valmistaja: #{manufacturer_filter}" : "Uusimmat tuotteet") : fallback_title
                end
            end

            title_to_draw = "Uusimmat tuotteet" if title_to_draw.to_s.empty?
            Curses.clear
            ui.draw(title_to_draw)

            selected_manufacturer
        end

        # Draw UI elements
        ui.draw("Uusimmat tuotteet")

        Curses.refresh

        # Listen to terminal resize
        Signal.trap("SIGWINCH") do
            resize_pending = true
        end

        # Create window for products
        window_height = Config.max_lines - Config.ui_bottom_lines - 2
        window_height = 1 if window_height < 1
        win = Curses::Window.new(window_height, Config.max_cols - 3, 1, 1)

        loop do
            if resize_pending
                resize_pending = false

                lines, cols = begin
                    IO.console.winsize
                rescue StandardError
                    [0, 0]
                end

                if lines.to_i <= 0 || cols.to_i <= 0
                    lines = Curses.lines
                    cols = Curses.cols
                end

                if lines.to_i <= 0 || cols.to_i <= 0
                    lines = Config.max_lines
                    cols = Config.max_cols
                end

                lines = lines.to_i
                cols = cols.to_i
                lines = 1 if lines < 1
                cols = 1 if cols < 1

                Config.max_lines = lines
                Config.max_cols = cols

                if Curses.respond_to?(:resizeterm)
                    begin
                        Curses.resizeterm(lines, cols)
                    rescue StandardError
                        # Ignore resize errors, we'll fall back to current size
                    end
                end

                if win
                    new_height = [Config.max_lines - Config.ui_bottom_lines - 2, 1].max
                    new_width = [Config.max_cols - 3, 1].max

                    begin
                        win.resize(new_height, new_width)
                    rescue StandardError
                        win.close if win.respond_to?(:close)
                        win = Curses::Window.new(new_height, new_width, 1, 1)
                    end

                    win.clear
                    win.refresh
                end

                Curses.clear
                ui.draw("")
                Curses.refresh
            end

            win.erase

            # Define products settings
            max_products = Config.max_lines - Config.ui_bottom_lines - 2
            max_products = 1 if max_products < 1

            # Get favorites
            favorite_products = favorites.get_favorites(original_products)
            handle_favorite_toggle = lambda do |target_product|
                next unless target_product

                favorites.favorite_product(target_product)
                favorite_products = favorites.get_favorites(original_products)
                if show == "favorites"
                    products = favorites.resolved_favorite_products(original_products)
                end
                ui.draw("")
            end

            # Text widths/positions
            row_width = [Config.max_cols - 4, 20].max
            column_gap = 2
            min_title_width = 10
            min_price_col_width = "▼ 1234 €".length
            absolute_max_price_col_width = 28
            price_col_start = 1
            available_price_space = row_width - min_title_width - column_gap
            max_price_col_width = [available_price_space, absolute_max_price_col_width].min
            max_price_col_width = [max_price_col_width, min_price_col_width].max
            format_price = lambda do |value|
                return "" if value.nil?
                numeric = value.to_f
                if (numeric % 1).zero?
                    numeric.to_i.to_s
                else
                    numeric.round(2).to_s
                end
            end
            # No products
            if products.empty?
                win.attron(Curses.color_pair(1)) do
                    text = "Tuotteita ei löytynyt."
                    win.setpos(Config.max_lines / 2 - 1, (Config.max_cols / 2 - text.length / 2))
                    win.addstr(text)
                end
            end

            if products.length > 0
                visible_products = products[start_row, max_products] || []
                price_text_limit = max_price_col_width

                row_entries = visible_products.map do |product|
                    missing_favorite = product['missing_favorite']
                    title_name = product['name'].to_s
                    title_name = "Tuote ##{product['id']}" if title_name.strip.empty?
                    title_name = "#{title_name} (myyty)" if missing_favorite

                    price_diff = 0
                    price_text = ""

                    if missing_favorite
                        stored_price = product['price']
                        price_text = if stored_price.nil?
                            "Ei hintaa"
                        else
                            "~ #{format_price.call(stored_price)} €"
                        end
                    else
                        price = product['price']
                        price_text = "#{format_price.call(price)} €"

                        price_history = data.get_product_price_history(product['id'])
                        previous_price = 0

                        if show == "price_drop" && product['price_drop']
                            previous_price = product['price_drop_from']
                            current_price_for_drop = product['price_drop_to']
                            price_diff = product['price_drop']
                            price_text = "▼ #{format_price.call(current_price_for_drop)} €"
                        elsif price_history.length > 0
                            if price_history.length > 1
                                previous_price = price_history[-2]["price"]
                            elsif price_history.length == 1
                                previous_price = price_history.last["price"]
                            end

                            price_diff = previous_price - price

                            if price_diff != 0 && price_diff < 0
                                price_text = "▲ #{format_price.call(previous_price)} € → #{format_price.call(price)} €"
                            end
                        end

                        if price_diff > 0
                            price_text = "▼ #{format_price.call(price)} €"
                        end
                    end

                    price_text = price_text.to_s.gsub(".", ",")
                    if price_text.length > price_text_limit
                        price_text = price_text[-price_text_limit, price_text_limit]
                    end

                    {
                        product: product,
                        title_name: title_name,
                        price_text: price_text,
                        price_diff: price_diff,
                        missing_favorite: missing_favorite
                    }
                end

                max_price_text_length = row_entries.map { |entry| entry[:price_text].length }.max || 0
                if max_price_text_length > min_price_col_width
                    price_col_width = [min_price_col_width + 1, max_price_col_width].min
                else
                    price_col_width = min_price_col_width
                end
                title_col_start = price_col_start + price_col_width + column_gap
                title_col_width = row_width - price_col_width - column_gap
                title_col_width = 1 if title_col_width < 1

                # List products
                row_entries.each_with_index do |entry, y|
                    product = entry[:product]
                    title_name = entry[:title_name]
                    price_text = entry[:price_text]
                    price_diff = entry[:price_diff]
                    missing_favorite = entry[:missing_favorite]
                    title_x = title_col_start
                    is_current_row = y == selection_position ? true : false

                    # Set position
                    win.setpos(y, 0)
                    win.clrtoeol

                    # Add star before favorite product title
                    if favorite_products.include?(product['id']) && title_col_width >= 2
                        color = if missing_favorite
                            is_current_row ? 8 : 7
                        else
                            is_current_row ? 2 : 7
                        end

                        win.attron(Curses.color_pair(color)) do
                            win.setpos(y, title_x)
                            win.addstr("★ ")
                        end

                        title_x += 2
                    end

                    # Product title
                    color = if missing_favorite
                        is_current_row ? 8 : 7
                    else
                        is_current_row ? 2 : 1
                    end

                    remaining_title_width = title_col_width - (title_x - title_col_start)
                    if remaining_title_width.positive?
                        title_text = title_name.dup
                        if title_text.length > remaining_title_width
                            truncate_at = [remaining_title_width - 3, 0].max
                            title_text = if truncate_at.positive?
                                "#{title_text[0, truncate_at]}..."
                            else
                                title_text[0, remaining_title_width]
                            end
                        end

                        win.attron(Curses.color_pair(color)) do
                            win.setpos(y, title_x)
                            win.addstr(title_text.ljust(remaining_title_width))
                        end
                    end

                    # Price color
                    color = if missing_favorite
                        is_current_row ? 8 : 7
                    else
                        is_current_row ? 2 : 3
                    end

                    if price_diff > 0
                        color = is_current_row ? 10 : 9
                    elsif price_diff < 0
                        color = is_current_row ? 8 : 7
                    end

                    # Product price
                    win.attron(Curses.color_pair(color)) do
                        win.setpos(y, price_col_start)
                        display_price_text = price_text
                        if display_price_text.length > price_col_width
                            display_price_text = display_price_text[-price_col_width, price_col_width]
                        end
                        win.addstr(display_price_text.rjust(price_col_width))
                    end

                    gap_color = is_current_row ? 2 : 1
                    if column_gap.positive?
                        win.attron(Curses.color_pair(gap_color)) do
                            win.setpos(y, price_col_start + price_col_width)
                            win.addstr(" " * column_gap)
                        end
                    end
                end
            end

            win.refresh

            # Handle keypresses
            key = if pending_key.nil?
                Curses.getch
            else
                next_key = pending_key
                pending_key = nil
                next_key
            end

            case key
                # Key up
                when Curses::Key::UP
                    if selection_position == 0 && start_row > 0
                        start_row -= 1
                        current_product -= 1
                    elsif selection_position > 0
                        selection_position -= 1
                        current_product -= 1
                    end

                # Key down
                when Curses::Key::DOWN
                    visible_count = if products.length.positive?
                        [products.length - start_row, max_products].min
                    else
                        0
                    end
                    visible_count = 0 if visible_count.negative?
                    next if visible_count.zero?

                    next_index = current_product + 1

                    if next_index < products.length
                        if selection_position == visible_count - 1
                            if start_row + visible_count < products.length
                                start_row += 1
                                current_product = next_index
                            end
                        elsif selection_position < visible_count - 1
                            selection_position += 1
                            current_product = next_index
                        end
                    end

                # Key home
                when Curses::Key::HOME
                    start_row = 0

                # Key page up
                when Curses::Key::PPAGE
                    start_row -= max_products

                # Key page down
                when Curses::Key::NPAGE
                    start_row += max_products

                # Sort by added
                when "1"
                    ui.draw("Uusimmat tuotteet")

                    if show == "added"
                        order = (order == "asc") ? "desc" : "asc"
                    else
                        order = "asc"
                    end

                    show = "added"
                    manufacturer_filter = nil
                    manufacturer_prev_state = nil
                    products = original_products.dup

                    if order == "desc"
                        products.reverse!
                    end

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Display products based on saved searches
                when "2"
                    ui.draw("Tallennettujen hakujen tuotteet")

                    search = Verkkis::Searches.new
                    searches = search.get_searches

                    # List all products having name matching the search term
                    products = original_products.select { |product| searches.any? { |search| product['name'].downcase.include?(search.downcase) } }
                    manufacturer_filter = nil
                    manufacturer_prev_state = nil

                    # Sort by name
                    products.sort_by! { |product| product['name'] }

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Show favorites
                when "3"
                    ui.draw("Suosikit")

                    favorite_products = favorites.get_favorites(original_products)
                    products = favorites.resolved_favorite_products(original_products)

                    show = "favorites"
                    manufacturer_filter = nil
                    manufacturer_prev_state = nil

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Sort by name
                when "4"
                    ui.draw("Tuotteet aakkosjärjestyksessä")

                    if show == "name"
                        order = (order == "asc") ? "desc" : "asc"
                    else
                        order = "asc"
                    end

                    show = "name"
                    manufacturer_filter = nil
                    manufacturer_prev_state = nil
                    products = original_products.dup
                    products.sort_by! { |product| product['name'] }

                    if order == "desc"
                        products.reverse!
                    end

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Sort by price
                when "5"
                    ui.draw("Tuotteet hinnan mukaan")

                    if show == "price"
                        order = (order == "asc") ? "desc" : "asc"
                    else
                        order = "asc"
                    end

                    show = "price"
                    manufacturer_filter = nil
                    manufacturer_prev_state = nil
                    products = original_products.dup
                    products.sort_by! { |product| product['price'] }

                    if order == "desc"
                        products.reverse!
                    end

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Show biggest price drops
                when "6"
                    ui.draw("Eniten alennetut tuotteet")

                    products = data.top_price_drops(original_products, 200)
                    show = "price_drop"
                    manufacturer_filter = nil
                    manufacturer_prev_state = nil

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # List saved searches on window
                when "h"
                    searches = Verkkis::Searches.new

                    search_result, forwarded_key = searches.list(ui)

                    if forwarded_key
                        pending_key = forwarded_key
                    end

                    if search_result
                        search_term = search_result
                        products = Verkkis::FuzzySearch.search_products(original_products, search_term)
                        manufacturer_filter = nil
                        manufacturer_prev_state = nil
                    end

                # Search
                when "e"
                    prompt = "Etsi: "
                    y_center = Config.max_lines / 2
                    box_height = 4

                    initial_box_width = [[Config.max_cols - 4, 80].min, 30].max
                    half_box_width = (initial_box_width * 0.5).floor
                    min_box_width = [prompt.length + 6, 20].max
                    max_box_width = [Config.max_cols - 4, min_box_width].max
                    box_width = [[half_box_width, min_box_width].max, max_box_width].min
                    base_box_width = box_width
                    input_width = box_width - 4

                    previous_title = ui.current_title
                    search_term = ""
                    cursor_pos = 0
                    display_offset = 0
                    dirty_layout = true
                    win_search = nil
                    search_cancelled = false
                    current_box_top = nil
                    current_box_left = nil
                    current_input_top = nil
                    current_input_left = nil
                    cleanup_search_ui = lambda do
                        if current_box_top && current_box_left && box_width && box_height
                            top = [current_box_top, 0].max
                            bottom = [current_box_top + box_height, Config.max_lines - 1].min
                            left = [current_box_left, 0].max
                            width = [box_width, Config.max_cols - left].min

                            (top..bottom).each do |row|
                                Curses.setpos(row, left)
                                Curses.addstr(" " * width)
                            end
                        else
                            Curses.clear
                        end

                        Curses.refresh
                    end
                    search_animation = lambda do
                        animation_win = nil
                        return unless current_box_top && current_box_left && box_width && box_height

                        frames = %w[| / - \\]
                        animation_steps = frames.length * 2
                        base_message = "Haetaan tuotteita"

                        interior_width = [box_width - 2, 1].max
                        max_width = [Config.max_cols - (current_box_left + 1), 1].max
                        animation_width = [[interior_width, base_message.length + 4].max, max_width].min

                        animation_row = current_box_top + (box_height / 2)
                        animation_row = [animation_row, current_box_top + 1].max
                        animation_row = [animation_row, current_box_top + box_height - 1].min
                        animation_col = current_box_left + 1

                        animation_win = Curses::Window.new(1, animation_width, animation_row, animation_col)

                        animation_win.attron(Curses.color_pair(1)) do
                            animation_steps.times do |i|
                                frame = frames[i % frames.length]
                                text = "#{base_message} #{frame}"
                                padding = [animation_width - text.length, 0].max
                                left_pad = padding / 2
                                right_pad = padding - left_pad
                                line = (" " * left_pad) + text + (" " * right_pad)
                                animation_win.setpos(0, 0)
                                animation_win.addstr(line[0, animation_width])
                                animation_win.refresh
                                sleep(0.08)
                            end
                        end
                    ensure
                        if animation_win
                            animation_win.clear
                            animation_win.refresh
                            animation_win.close if animation_win.respond_to?(:close)
                        end
                    end

                    backspace_keys = [127]
                    backspace_keys << Curses::Key::BACKSPACE if defined?(Curses::Key::BACKSPACE)
                    delete_key = defined?(Curses::Key::DC) ? Curses::Key::DC : nil
                    left_key = defined?(Curses::Key::LEFT) ? Curses::Key::LEFT : nil
                    right_key = defined?(Curses::Key::RIGHT) ? Curses::Key::RIGHT : nil
                    resize_key = defined?(Curses::Key::RESIZE) ? Curses::Key::RESIZE : nil
                    enter_keys = [10]
                    enter_keys << Curses::Key::ENTER if defined?(Curses::Key::ENTER)
                    cancel_keys = [27]
                    cancel_keys << "\e"
                    cancel_keys << Curses::Key::EXIT if defined?(Curses::Key::EXIT)

                    calculate_layout = lambda do |width|
                        box_top = [[y_center - 2, 0].max, Config.max_lines - box_height - 1].min
                        box_left = [[(Config.max_cols - width) / 2, 0].max, Config.max_cols - width - 1].min
                        input_top = box_top + 2
                        input_left = box_left + 2
                        [box_top, box_left, input_top, input_left]
                    end

                    render_layout = lambda do
                        box_top, box_left, input_top, input_left = calculate_layout.call(box_width)
                        current_box_top = box_top
                        current_box_left = box_left
                        current_input_top = input_top
                        current_input_left = input_left
                        Curses.clear
                        ui.draw('Etsi tuotetta')
                        ui.box(box_height, box_width, box_top, box_left)
                        window = Curses::Window.new(1, input_width, input_top, input_left)
                        window.keypad(true)
                        [window, box_top, box_left, input_top, input_left]
                    end

                    refresh_input = lambda do
                        return unless win_search

                        available_space = input_width - prompt.length
                        available_space = 1 if available_space <= 0

                        if cursor_pos < display_offset
                            display_offset = cursor_pos
                        elsif cursor_pos - display_offset > available_space
                            display_offset = cursor_pos - available_space
                        elsif search_term.length - display_offset < available_space
                            display_offset = [search_term.length - available_space, 0].max
                        end

                        visible_term = search_term[display_offset, available_space] || ""

                        win_search.attron(Curses.color_pair(1)) do
                            win_search.erase
                            win_search.setpos(0, 0)
                            win_search.addstr(prompt)
                            win_search.addstr(visible_term)
                            win_search.addstr(" " * [available_space - visible_term.length, 0].max)
                        end

                        cursor_column = prompt.length + cursor_pos - display_offset
                        cursor_column = prompt.length if cursor_column < prompt.length
                        cursor_column = prompt.length + available_space if cursor_column > prompt.length + available_space
                        win_search.setpos(0, cursor_column)
                        win_search.refresh
                    end

                    begin
                        Curses.curs_set(1)
                        Curses.noecho

                        loop do
                            max_box_width = [Config.max_cols - 4, min_box_width].max
                            adjusted_box_width = [[box_width, max_box_width].min, min_box_width].max

                            if adjusted_box_width != box_width
                                box_width = adjusted_box_width
                                input_width = box_width - 4
                                dirty_layout = true
                            else
                                input_width = box_width - 4
                            end

                            if dirty_layout
                                win_search, _box_top, _box_left, _input_top, _input_left = render_layout.call
                                dirty_layout = false
                            end

                            refresh_input.call

                            ch = win_search.getch
                            break if ch.nil?

                            if cancel_keys.include?(ch) || (defined?(Curses::Key::CANCEL) && ch == Curses::Key::CANCEL)
                                if search_term.length.zero?
                                    search_cancelled = true
                                    Curses.flushinp if Curses.respond_to?(:flushinp)
                                    break
                                else
                                    search_term = ""
                                    cursor_pos = 0
                                    display_offset = 0
                                    box_width = base_box_width
                                    input_width = box_width - 4
                                    dirty_layout = true
                                    Curses.flushinp if Curses.respond_to?(:flushinp)
                                    refresh_input.call
                                    next
                                end
                            end

                            if resize_key && ch == resize_key
                                dirty_layout = true
                                next
                            end

                            if enter_keys.include?(ch)
                                break
                            elsif backspace_keys.include?(ch)
                                if cursor_pos > 0
                                    search_term.slice!(cursor_pos - 1)
                                    cursor_pos -= 1
                                end
                            elsif delete_key && ch == delete_key
                                search_term.slice!(cursor_pos) if cursor_pos < search_term.length
                            elsif left_key && ch == left_key
                                cursor_pos -= 1 if cursor_pos > 0
                            elsif right_key && ch == right_key
                                cursor_pos += 1 if cursor_pos < search_term.length
                            else
                                character = nil

                                if ch.is_a?(String)
                                    character = ch
                                elsif ch.is_a?(Integer) && ch >= 32 && ch <= 126
                                    character = ch.chr
                                end

                                if character
                                    search_term.insert(cursor_pos, character)
                                    cursor_pos += 1
                                end
                            end

                            cursor_pos = 0 if cursor_pos.negative?
                            cursor_pos = search_term.length if cursor_pos > search_term.length

                            needed_input_width = prompt.length + search_term.length + 1
                            if needed_input_width > input_width && box_width < max_box_width
                                new_box_width = [needed_input_width + 4, max_box_width].min
                                if new_box_width > box_width
                                    box_width = new_box_width
                                    input_width = box_width - 4
                                    dirty_layout = true
                                end
                            end
                        end
                    ensure
                        Curses.curs_set(0)
                        Curses.noecho
                        if win_search
                            win_search.clear
                            win_search.refresh
                            win_search.close if win_search.respond_to?(:close)
                        end
                    end

                    if search_cancelled
                        restored_title = previous_title.to_s.empty? ? "Uusimmat tuotteet" : previous_title
                        cleanup_search_ui.call
                        ui.draw(restored_title)
                    elsif search_term.length > 0
                        search_animation.call
                        cleanup_search_ui.call
                        products = Verkkis::FuzzySearch.search_products(original_products, search_term)
                        manufacturer_filter = nil
                        manufacturer_prev_state = nil
                        ui.draw("Haku: " + search_term)
                    else
                        cleanup_search_ui.call
                        products = original_products.dup
                        manufacturer_filter = nil
                        manufacturer_prev_state = nil
                        ui.draw("Uusimmat tuotteet")
                    end

                    unless search_cancelled
                        start_row = 0
                        selection_position = 0
                        current_product = 0
                    end

                # Display product information when enter pressed
                when "i", 10, Curses::Key::RIGHT
                    product_info = Verkkis::ProductInfo.new
                    selected_product = products[current_product]
                    price_history = data.get_product_price_history(selected_product['id'])
                    product_info.view(ui, selected_product, price_history)

                # List manufacturers when pressing "v"
                when "v"
                    select_manufacturer.call(ui.current_title, capture_previous: show != "manufacturer")

                # Update products
                when "p", Curses::Key::F5
                    ui.draw("Tuotteiden päivitys")
                    Curses.refresh

                    data = Verkkis::Data.new
                    data.update_data

                    # Load updated products
                    products = data.get_products
                    original_products = products.dup
                    manufacturer_filter = nil
                    manufacturer_prev_state = nil

                    # Get updated price history data in data @price_history
                    data.get_price_history

                    ui.draw("")

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Favorite item
                when "."
                    handle_favorite_toggle.call(products[current_product])

                when *favorite_delete_keys
                    handle_favorite_toggle.call(products[current_product]) if show == "favorites"

                # Save search
                when "t"
                    search = Verkkis::Searches.new
                    search.save_search(ui, search_term)
                    ui.draw("")

                # Open product page in browser
                when "a"
                    product = products[current_product]
                    Launchy.open("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")

                # Escape
                when 27
                    Curses.flushinp if Curses.respond_to?(:flushinp)

                    default_view_active = (
                        show == "added" &&
                        manufacturer_filter.nil? &&
                        manufacturer_prev_state.nil? &&
                        order == "desc" &&
                        start_row.zero? &&
                        selection_position.zero? &&
                        current_product.zero? &&
                        (search_term.to_s.empty?) &&
                        products == original_products
                    )

                    if show == "manufacturer"
                        select_manufacturer.call(ui.current_title, capture_previous: false)
                    elsif default_view_active
                        break
                    else
                        manufacturer_filter = nil
                        manufacturer_prev_state = nil
                        search_term = ""
                        show = "added"
                        order = "desc"
                        start_row = 0
                        selection_position = 0
                        current_product = 0
                        ui.draw("Uusimmat tuotteet")
                        products = original_products.dup
                    end

                when 'q'
                    break
            end

            # Keep paging bounds sane after handling input
            max_start_row = [products.length - max_products, 0].max
            start_row = [[start_row, 0].max, max_start_row].min

            visible_count = [products.length - start_row, max_products].min
            visible_count = 0 if visible_count.negative?

            if visible_count.zero?
                selection_position = 0
                current_product = 0
            else
                selection_position = [[selection_position, 0].max, visible_count - 1].min
                current_product = start_row + selection_position
                if current_product >= products.length
                    current_product = products.length - 1
                    selection_position = [current_product - start_row, 0].max
                end
            end
        end
    ensure
        Curses.close_screen
        print "\e[?1049l"
    end
end

main
