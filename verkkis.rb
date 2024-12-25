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
        original_products = products

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
                        previous_price = price_history.last["price"]
                        price_diff = previous_price - price
                    end

                    color = is_current_row ? 2 : 3

                    if price_diff > 0
                        color = is_current_row ? 10 : 9
                    elsif price_diff < 0
                        color = is_current_row ? 8 : 7
                    end

                    if price_diff != 0
                        if (price_diff > 0)
                            price_text = "▼ #{previous_price} € → #{price} €"
                        elsif (price_diff < 0)
                            price_text = "▲ #{previous_price} € → #{price} €"
                        end
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
                    products = original_products

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
                    products = original_products
                    products = products.select { |product| favorite_products.include?(product['id']) }

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
                    products = original_products
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
                    products = original_products
                    products.sort_by! { |product| product['price'] }

                    if order == "desc"
                        products.reverse!
                    end

                    start_row = 0
                    selection_position = 0
                    current_product = 0
                    show = "asc"

                # List saved searches on window
                when "h"
                    searches = Verkkis::Searches.new
                    searches = searches.list(ui)

                # Search
                when "e"
                    y_pos = Config.max_lines / 2
                    x_pos = Config.max_cols / 2

                    ui.draw('Etsi tuotetta')
                    ui.box(4, 40, y_pos - 1, x_pos - 15)

                    win_search = Curses::Window.new(1, 20, y_pos + 1, x_pos - 10) # h, w, y, x

                    win_search.attron(Curses.color_pair(1)) do
                        win_search.erase
                        win_search.setpos(0, 0)
                        win_search.addstr("Etsi: ")
                    end

                    # Read search term
                    search_term = win_search.getstr

                    if search_term.length > 0
                        products = original_products.select { |product| product['name'].downcase.include?(search_term.downcase) }
                        ui.draw("Hakutulokset: " + search_term)
                    else
                        # Reset
                        products = original_products
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
                    search.save_search(search_term)
                    ui.draw("")

                # Open product page in browser
                when "o"
                    product = products[current_product]
                    Launchy.open("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")

                # Escape
                when 27
                    ui.draw("Uusimmat tuotteet")
                    products = original_products

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
