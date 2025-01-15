require 'net/http'
require 'json'
require 'uri'
require 'curses'

module Verkkis
    class Data
        API_URL = "https://web-api.service.verkkokauppa.com/search?private=true&sort=releaseDate%3Adesc&lang=fi&isCustomerReturn=true&pageSize=99&pageNo="
        LOADING_BAR_LENGTH = 30
        HEADERS = {
            "User-Agent" => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:33.0) Gecko/20100101 Firefox/33.0",
            "Accept-Language" => "en-US,en;q=0.5",
            "Connection" => "keep-alive"
        }

        attr_reader :products
        attr_reader :total_pages
        attr_reader :price_history

        # Initialize
        def initialize
            @products = []
            @total_pages = 1
            @price_history = get_price_history
        end

        # Get URL
        def get_url(page)
            "#{API_URL}#{page}"
        end

        # Get file path
        def get_file_path
            File.join(File.expand_path("..", __dir__), ".data/data.json")
        end

        # Get price history file path
        def get_price_history_file_path
            File.join(File.expand_path("..", __dir__), ".data/price_history.json")
        end

        # Get products
        def get_products
            if File.exist?(get_file_path)
                JSON.parse(File.read(get_file_path))
            else
                []
            end
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error while reading data from disk! #{e.message}")
            Curses.refresh
            exit
        end

        # Get product price history
        def get_price_history
            if File.exist?(get_price_history_file_path)
                JSON.parse(File.read(get_price_history_file_path))
            else
                {}
            end
        end

        # Get product's price history
        def get_product_price_history(product_id)
            @price_history[product_id.to_s] || []
        end

        # Update data
        def update_data
            win = Curses::Window.new(Config.max_lines - Config.ui_bottom_lines - 1, Config.max_cols - 3, 1, 1)
            win.clear

            text = "Päivitetään tuotteita..."
            win.setpos(Config.max_lines / 2 - 2, Config.max_cols / 2 - text.length / 2)
            win.addstr(text)
            win.refresh

            # Get total pages
            url = get_url(0)
            @total_pages = get_total_pages_from_url(url)

            unless @total_pages
                text = "Sivujen lukumäärää ei saatu."
                win.setpos(Config.max_lines / 2 - 1, Config.max_cols / 2 - text.length / 2)
                win.addstr(text)
                win.refresh
                exit
            end

            # Get all data
            page = 0

            loop do
                url = get_url(page)
                data = get_data_from_url(url)

                percent = ((page.to_f / @total_pages) * 100).round
                loaded = ((percent.to_f / 100) * LOADING_BAR_LENGTH).round

                loading_bar_loaded = '▓' * loaded
                loading_bar_remaining = '░' * (LOADING_BAR_LENGTH - loaded)

                win.setpos(Config.max_lines / 2, Config.max_cols / 2 - 23)
                win.addstr("%#{@total_pages.to_s.length}d/%d [%s%s] %d%%" % [page, @total_pages, loading_bar_loaded, loading_bar_remaining, percent])
                win.refresh

                break if data.nil?

                get_products_from_data(data)
                page += 1
                break if page > @total_pages
            end

            save_price_history
            save_data

            win.setpos(4, 0)
            win.addstr("Update complete")
            win.refresh
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error during update: #{e.message}")
            Curses.refresh
            exit
        end

        private

        # Save data
        def save_data
            File.write(get_file_path, JSON.pretty_generate(@products))
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error while saving data: #{e.message}")
            Curses.refresh
            exit
        end

        # Save price history
        def save_price_history
            # Load existing price history or initialize an empty hash
            price_history = if File.exist?(get_price_history_file_path)
                JSON.parse(File.read(get_price_history_file_path))
            else
                {}
            end

            # Collect IDs of currently available products
            current_product_ids = @products.map { |product| product[:id] }

            @products.each do |product|
                product_id = product[:id].to_s # Ensure product ID is a string for consistency
                price = product[:price]

                # Check if price history exists for this product
                if price_history[product_id]
                    # Get the most recent price entry
                    last_entry = price_history[product_id].last

                    # Add a new entry only if the price has changed
                    if last_entry["price"] != price
                        price_history[product_id] << { "price" => price, "date" => Time.now.to_i }
                    end
                else
                    # If no price history exists, initialize it with the current price
                    price_history[product_id] = [{ "price" => price, "date" => Time.now.to_i }]
                end
            end

            # Remove products that no longer exist
            price_history.keys.each do |product_id|
                price_history.delete(product_id) unless current_product_ids.include?(product_id.to_i)
            end

            # Write updated price history to file
            File.write(get_price_history_file_path, JSON.pretty_generate(price_history))
        end

        # Get data from URL
        def get_data_from_url(url)
            uri = URI(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Get.new(uri, HEADERS)
            response = http.request(request)
            data = JSON.parse(response.body)

            if data["message"]
                Curses.setpos(Curses.lines - 1, 0)
                Curses.addstr("Error while getting data: #{data["message"]}")
                Curses.refresh
                return nil
            end

            data
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("HTTP error: #{e.message}")
            Curses.refresh
            nil
        end

        # Get total pages from URL
        def get_total_pages_from_url(url)
            json = get_data_from_url(url)
            return nil if json.nil?

            if json["numPages"]
                json["numPages"].to_i
            else
                Curses.setpos(Curses.lines - 1, 0)
                Curses.addstr("Missing total page count from response!")
                Curses.refresh
                nil
            end
        end

        # Get products from data
        def get_products_from_data(data)
            products_data = data["products"]

            products = products_data.map do |product|
                {
                    id: product["customerReturnsInfo"]["id"],
                    name: product["name"],
                    description: product["descriptionShort"],
                    return_info: product["customerReturnsInfo"]["product_extra_info"],
                    price: product["customerReturnsInfo"]["price_with_tax"],
                    original_price: product.dig("price", "current"),
                    condition: product["customerReturnsInfo"]["condition"]
                }
            end

            @products.concat(products)
        end
    end
end
