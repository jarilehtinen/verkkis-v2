require 'curses'
require 'launchy'
require 'json'
require_relative 'lib/config'
require_relative 'lib/data'
require_relative 'lib/favorites'
require_relative 'lib/searches'
require_relative 'lib/ui'

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
        ui.draw

        Curses.refresh

        # Listen to terminal resize
        Signal.trap("SIGWINCH") do
            # Toimenpiteet terminaalin koon muuttuessa
            Config.max_lines = Curses.lines
            Config.max_cols = Curses.cols
            Curses.clear
            ui.draw
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
                    win.setpos(Config.max_lines / 2, (Config.max_cols / 2 - text.length / 2))
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
                    price = product['price'].round

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
                        win.addstr(price_text.rjust(20))
                    end
                end
            end

            win.refresh

            # Handle keypresses
            case Curses.getch

            when Curses::Key::UP
                if selection_position == 0 && start_row > 0
                    start_row -= 1
                    current_product -= 1
                elsif selection_position > 0
                    selection_position -= 1
                    current_product -= 1
                end

            when Curses::Key::DOWN
                if selection_position == max_products - 1 && start_row + max_products < products.length
                    start_row += 1
                    current_product += 1
                elsif selection_position < max_products - 1
                    selection_position += 1
                    current_product += 1
                end

            when Curses::Key::HOME
                start_row = 0

            when Curses::Key::NPAGE
                start_row -= max_products

            when Curses::Key::NPAGE
                start_row += max_products

            # Sort by name
            when "a"
                Curses.clrtoeol
                ui.draw

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
            when "h"
                Curses.clrtoeol
                ui.draw

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

            # Sort by added
            when "u"
                Curses.clrtoeol
                ui.draw

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
            when "l"
                Curses.setpos(Config.max_lines - 1, 0)
                Curses.clrtoeol
                ui.draw

                search = Verkkis::Searches.new
                searches = search.get_searches

                # List all products having name matching the search term
                products = original_products.select { |product| searches.any? { |search| product['name'].downcase.include?(search.downcase) } }

                # Sort by name
                products.sort_by! { |product| product['name'] }

                start_row = 0
                selection_position = 0
                current_product = 0

            # List saved searches on window
            when "z"
                Curses.setpos(Config.max_lines - 1, 0)
                Curses.clrtoeol
                ui.draw

                search = Verkkis::Searches.new
                searches = search.get_searches

                ui.title("Tallennetut haut")

                if searches
                    searches.each_with_index do |search_term, i|
                        win.setpos(i, 1)
                        win.addstr("#{i + 1}. #{search_term}")
                    end
                end

                win.refresh

                key = win.getch

                if key =~ /\d/
                    index = key.to_i - 1
                    if index >= 0 && index < searches.length
                        search.delete_search(searches[index])
                        ui.draw
                    end
                end

            # Search
            when "e"
                Curses.setpos(Config.max_lines - 1, 0)
                Curses.clrtoeol

                Curses.flushinp
                Curses.refresh

                Curses.setpos(Config.max_lines - 1, 1)
                Curses.addstr("Etsi: ")

                # Read search term
                search_term = Curses.getstr

                if search_term.length > 0
                    products = original_products.select { |product| product['name'].downcase.include?(search_term.downcase) }
                    ui.draw
                else
                    # Reset
                    products = original_products
                    ui.draw
                end

                ui.title("Etsi: " + search_term)

                start_row = 0
                selection_position = 0
                current_product = 0

            # Display product information when enter pressed
            when "i", 10, Curses::Key::RIGHT
                Curses.flushinp
                product = products[current_product + 1]
                ui.title(product['name'])
                Curses.refresh

                loop do
                    win.erase

                    win.attron(Curses.color_pair(5) | Curses::A_BOLD) do
                        win.setpos(1, 3)
                        win.addstr("#{product['name']}")
                    end

                    win.attron(Curses.color_pair(5)) do
                        win.setpos(3, 3)
                        win.addstr("#{product['description']}")
                        win.setpos(5, 3)
                        text = "Hinta:  #{product['price']} €"

                        if product['original_price']
                            text += " (#{product['original_price']} €)"
                        end

                        win.addstr(text)
                        win.setpos(6, 3)
                        win.addstr("Kunto:  #{product['condition']}")
                    end

                    win.attron(Curses.color_pair(6)) do
                        win.setpos(9, 3)
                        win.addstr("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")
                    end

                    win.refresh

                    key = win.getch

                    if key == "o"
                        Launchy.open("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")
                    elsif key == "q" || key == 27 || key == Curses::Key::LEFT
                        break
                    end
                end

                ui.draw

            # Update products
            when "p", Curses::Key::F5
                data = Verkkis::Data.new
                data.update_data

                # Load updated products
                products = data.get_products

                # Get updated price history data in data @price_history
                data.get_price_history

                ui.draw

                start_row = 0
                selection_position = 0
                current_product = 0

            # Favorite item
            when "."
                product = products[current_product + 1]
                favorites.favorite_product(product['id'])
                ui.draw

            # Save search
            when "t"
                search = Verkkis::Searches.new
                search.save_search(search_term)
                ui.draw

            # Show favorites
            when "s"
                Curses.setpos(Config.max_lines - 1, 0)
                Curses.clrtoeol
                ui.draw

                favorite_products = favorites.get_favorites
                products = original_products
                products = products.select { |product| favorite_products.include?(product['id']) }

                show = "favorites"

                start_row = 0
                selection_position = 0
                current_product = 0

            # Open product page in browser
            when "o"
                product = products[current_product + 1]
                Launchy.open("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")

            # Escape
            when 27
                Curses.flushinp
                products = original_products
                Curses.refresh

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
