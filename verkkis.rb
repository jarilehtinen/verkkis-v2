require 'curses'
require 'launchy'
require 'json'
require_relative 'lib/config'
require_relative 'lib/data'
require_relative 'lib/favorites'
require_relative 'lib/searches'
require_relative 'lib/ui'
require_relative 'lib/manufacturers'
require_relative 'lib/productinfo'

def main
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

    # Laita window.keypad päälle
    Curses.stdscr.keypad(true)

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

        # Lines and cols
        Config.max_lines = Curses.lines
        Config.max_cols = Curses.cols

        # Load products
        products = data.get_products

        # Store products for resetting
        original_products = products.dup

        # Draw UI elements
        ui.draw("Uusimmat tuotteet")

        Curses.refresh

        # Listen to terminal resize
        Signal.trap("SIGWINCH") do
            # Toimenpiteet terminaalin koon muuttuessa
            Config.max_lines = Curses.lines
            Config.max_cols = Curses.cols
            Curses.clear
            ui.draw("")
            Curses.refresh
        end

        # Create window for products
        win = Curses::Window.new(Config.max_lines - Config.ui_bottom_lines - 1, Config.max_cols - 3, 1, 1)

        loop do
            win.erase

            # Define products settings
            max_products = Config.max_lines - Config.ui_bottom_lines - 1

            # Get favorites
            favorite_products = favorites.get_favorites

            # Text widths/positions
            title_col_width = Config.max_cols - 12
            price_col_start = title_col_width - 11

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

                # List products
                visible_products.each_with_index do |product, y|
                    x = 1
                    is_current_row = y == selection_position ? true : false

                    # Product title
                    title = product['name'][0, title_col_width - 10] + "..." if product['name'].length > title_col_width - 10
                    title ||= product['name']

                    # Product price
                    price = product['price']

                    # Price text
                    price_text = "#{price} €"

                    # Set position
                    win.setpos(y, 0)
                    win.clrtoeol

                    # Add star before favorite product title
                    if (favorite_products.include?(product['id']))
                        color = is_current_row ? 2 : 7

                        win.attron(Curses.color_pair(color)) do
                            win.setpos(y, x)
                            win.addstr("★ ")
                        end

                        x = 3
                    end

                    # Product title
                    color = is_current_row ? 2 : 1

                    win.attron(Curses.color_pair(color)) do
                        win.setpos(y, x)
                        win.addstr(title.ljust(title_col_width))
                    end

                    # Previous price
                    price_history = data.get_product_price_history(product['id'])
                    price_diff = 0
                    previous_price = 0

                    if price_history.length > 0
                        if price_history.length > 1
                            previous_price = price_history[-2]["price"]
                        elsif price_history.length == 1
                            previous_price = price_history.last["price"]
                        end

                        price_diff = previous_price - price

                        if price_diff != 0
                            if (price_diff > 0)
                                price_text = "▼ #{previous_price} € → #{price} €"
                            elsif (price_diff < 0)
                                price_text = "▲ #{previous_price} € → #{price} €"
                            end
                        end
                    end

                    # Price color
                    color = is_current_row ? 2 : 3

                    if price_diff > 0
                        color = is_current_row ? 10 : 9
                    elsif price_diff < 0
                        color = is_current_row ? 8 : 7
                    end

                    # Product price
                    win.attron(Curses.color_pair(color)) do
                        win.setpos(y, price_col_start)

                        # Replace dots to commas in price text
                        price_text = price_text.gsub(".", ",")

                        win.addstr(price_text.to_s.rjust(20))
                    end
                end
            end

            win.refresh

            # Handle keypresses
            case Curses.getch
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
                    if selection_position == max_products - 1 && start_row + max_products < products.length
                        start_row += 1
                        current_product += 1
                    elsif selection_position < max_products - 1
                        selection_position += 1
                        current_product += 1
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

                    # Sort by name
                    products.sort_by! { |product| product['name'] }

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Show favorites
                when "3"
                    ui.draw("Suosikit")

                    favorite_products = favorites.get_favorites
                    products = original_products.select { |product| favorite_products.include?(product['id']) }

                    show = "favorites"

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
                    products = original_products.dup
                    products.sort_by! { |product| product['price'] }

                    if order == "desc"
                        products.reverse!
                    end

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # List saved searches on window
                when "h"
                    searches = Verkkis::Searches.new

                    # loop do
                    search_term = searches.list(ui)

                    if search_term
                        products = original_products.select { |product| product['name'].downcase.include?(search_term.downcase) }
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
                    input_width = box_width - 4

                    search_term = ""
                    cursor_pos = 0
                    display_offset = 0
                    dirty_layout = true
                    win_search = nil

                    backspace_keys = [127]
                    backspace_keys << Curses::Key::BACKSPACE if defined?(Curses::Key::BACKSPACE)
                    delete_key = defined?(Curses::Key::DC) ? Curses::Key::DC : nil
                    left_key = defined?(Curses::Key::LEFT) ? Curses::Key::LEFT : nil
                    right_key = defined?(Curses::Key::RIGHT) ? Curses::Key::RIGHT : nil
                    resize_key = defined?(Curses::Key::RESIZE) ? Curses::Key::RESIZE : nil
                    enter_keys = [10]
                    enter_keys << Curses::Key::ENTER if defined?(Curses::Key::ENTER)

                    calculate_layout = lambda do |width|
                        box_top = [[y_center - 2, 0].max, Config.max_lines - box_height - 1].min
                        box_left = [[(Config.max_cols - width) / 2, 0].max, Config.max_cols - width - 1].min
                        input_top = box_top + 2
                        input_left = box_left + 2
                        [box_top, box_left, input_top, input_left]
                    end

                    render_layout = lambda do
                        box_top, box_left, input_top, input_left = calculate_layout.call(box_width)
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
                    end

                    if search_term.length > 0
                        products = original_products.select { |product| product['name'].downcase.include?(search_term.downcase) }
                        ui.draw("Haku: " + search_term)
                    else
                        products = original_products.dup
                        ui.draw("Uusimmat tuotteet")
                    end

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Display product information when enter pressed
                when "i", 10, Curses::Key::RIGHT
                    product_info = Verkkis::ProductInfo.new
                    product_info.view(ui, products[current_product])

                # List manufacturers when pressing "v"
                # Work in progress
                when "v"
                    manufacturers = Verkkis::Manufacturers.new
                    manufacturers.list(ui, products)

                # Update products
                when "p", Curses::Key::F5
                    ui.draw("Tuotteiden päivitys")
                    Curses.refresh

                    data = Verkkis::Data.new
                    data.update_data

                    # Load updated products
                    products = data.get_products
                    original_products = products.dup

                    # Get updated price history data in data @price_history
                    data.get_price_history

                    ui.draw("")

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                # Favorite item
                when "."
                    product = products[current_product]
                    favorites.favorite_product(product['id'])
                    ui.draw("")

                # Save search
                when "t"
                    search = Verkkis::Searches.new
                    search.save_search(ui, search_term)
                    ui.draw("")

                # Open product page in browser
                when "o"
                    product = products[current_product]
                    Launchy.open("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")

                # Escape
                when 27
                    ui.draw("Uusimmat tuotteet")
                    products = original_products.dup

                    start_row = 0
                    selection_position = 0
                    current_product = 0

                when 'q'
                    break
            end
        end
    ensure
        Curses.close_screen
        print "\e[?1049l"
    end
end

main
