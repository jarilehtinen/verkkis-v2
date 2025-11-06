require 'net/http'
require 'json'
require 'uri'
require 'curses'
require 'fileutils'
require 'time'
require 'openssl'

module Verkkis
    class Data
        API_URL = "https://web-api.service.verkkokauppa.com/search?private=true&sort=releaseDate%3Adesc&lang=fi&isCustomerReturn=true&pageSize=99&pageNo="
        LOADING_BAR_LENGTH = 30
        HEADERS = {
            "User-Agent" => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:33.0) Gecko/20100101 Firefox/33.0",
            "Accept-Language" => "en-US,en;q=0.5",
            "Connection" => "keep-alive"
        }
        SSL_SKIP_ENV = "VERKKIS_SKIP_SSL_VERIFY"

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

        def get_debug_log_path
            File.join(File.expand_path("..", __dir__), ".data/debug.log")
        end

        def get_error_log_path
            File.join(File.expand_path("..", __dir__), ".data/error.log")
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
            error_log("Error while reading data from disk: #{e.message}\n#{e.backtrace.join("\n")}")
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

        # Return products with the largest price drops
        def top_price_drops(products, limit = 200)
            # Build lookup to match history entries against current product data
            indexed_products = products.each_with_object({}) do |product, memo|
                memo[product['id'].to_s] = product
            end

            drops = @price_history.each_with_object([]) do |(product_id, entries), acc|
                product = indexed_products[product_id]
                next unless product
                next if entries.nil? || entries.empty?

                max_price = entries.map { |entry| entry['price'].to_f }.max
                current_price = product['price'].to_f
                drop_amount = max_price - current_price
                drop_percent = max_price.positive? ? ((drop_amount / max_price) * 100.0) : 0.0

                next unless drop_amount.positive? && drop_percent.positive?

                acc << product.merge(
                    'price_drop' => drop_amount.round(2),
                    'price_drop_from' => max_price,
                    'price_drop_to' => current_price,
                    'price_drop_percent' => drop_percent
                )
            end

            drops.sort_by { |item| [-item['price_drop'].to_f, -item['price_drop_percent'].to_f] }.first(limit)
        end

        # Update data
        def update_data
            debug_log("Starting data update")
            win = Curses::Window.new(Config.max_lines - Config.ui_bottom_lines - 1, Config.max_cols - 3, 1, 1)
            win.clear

            text = "Päivitetään tuotteita..."
            win.setpos(Config.max_lines / 2 - 2, Config.max_cols / 2 - text.length / 2)
            win.addstr(text)
            win.refresh

            # Get total pages
            url = get_url(0)
            @total_pages = get_total_pages_from_url(url)
            debug_log("Total pages resolved to #{@total_pages} from #{url}")

            unless @total_pages
                error_log("Total page count missing for #{url}")
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
                debug_log("Requesting page #{page} from #{url}")
                data = get_data_from_url(url)
                debug_log("Page #{page} response #{data.nil? ? 'nil' : 'received'}")

                percent = ((page.to_f / @total_pages) * 100).round
                loaded = ((percent.to_f / 100) * LOADING_BAR_LENGTH).round

                loading_bar_loaded = '▓' * loaded
                loading_bar_remaining = '░' * (LOADING_BAR_LENGTH - loaded)

                win.setpos(Config.max_lines / 2, Config.max_cols / 2 - 23)
                win.addstr("%#{@total_pages.to_s.length}d/%d [%s%s] %d%%" % [page, @total_pages, loading_bar_loaded, loading_bar_remaining, percent])
                win.refresh

                break if data.nil?

                get_products_from_data(data)
                debug_log("Accumulated products count: #{@products.length}")
                page += 1
                break if page > @total_pages
            end

            save_price_history
            save_data

            win.setpos(4, 0)
            win.addstr("Update complete")
            win.refresh
            debug_log("Data update finished")
        rescue StandardError => e
            error_log("Error during update: #{e.message}\n#{e.backtrace.join("\n")}")
            debug_log("Error during update: #{e.message}\n#{e.backtrace.join("\n")}")
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error during update: #{e.message}")
            Curses.refresh
            exit
        end

        private

        # Save data
        def save_data
            debug_log("Saving #{@products.length} products to #{get_file_path}")
            File.write(get_file_path, JSON.pretty_generate(@products))
        rescue StandardError => e
            error_log("Error while saving data: #{e.message}\n#{e.backtrace.join("\n")}")
            debug_log("Error while saving data: #{e.message}\n#{e.backtrace.join("\n")}")
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
            debug_log("Saving price history for #{price_history.keys.length} products")
            File.write(get_price_history_file_path, JSON.pretty_generate(price_history))
        end

        # Get data from URL
        def get_data_from_url(url)
            uri = URI(url)
            debug_log("Preparing HTTP GET #{uri}")
            response = perform_request(uri)
            debug_log("HTTP #{response.code} received for #{uri}")
            data = JSON.parse(response.body)

            if data["message"]
                debug_log("API returned message for #{uri}: #{data['message']}")
                error_log("API returned error for #{uri}: #{data['message']}")
                Curses.setpos(Curses.lines - 1, 0)
                Curses.addstr("Error while getting data: #{data["message"]}")
                Curses.refresh
                return nil
            end

            data
        rescue OpenSSL::SSL::SSLError => e
            error_log("SSL error when fetching #{url}: #{e.message}\n#{e.backtrace.join("\n")}")
            debug_log("SSL error when fetching #{url}: #{e.message}")
            unless ssl_verification_disabled?
                note = "Set #{SSL_SKIP_ENV}=1 to retry without certificate verification (insecure)."
                error_log(note)
                debug_log(note)
            end
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("HTTP error: #{e.message}")
            Curses.refresh
            nil
        rescue StandardError => e
            error_log("HTTP error when fetching #{url}: #{e.message}\n#{e.backtrace.join("\n")}")
            debug_log("HTTP error when fetching #{url}: #{e.message}\n#{e.backtrace.join("\n")}")
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("HTTP error: #{e.message}")
            Curses.refresh
            nil
        end

        # Get total pages from URL
        def get_total_pages_from_url(url)
            json = get_data_from_url(url)
            debug_log("Total pages response for #{url} is #{json.nil? ? 'nil' : 'present'}")
            return nil if json.nil?

            if json["numPages"]
                value = json["numPages"].to_i
                debug_log("numPages from response: #{value}")
                value
            else
                error_log("numPages missing in response for #{url}")
                debug_log("numPages missing in response for #{url}")
                Curses.setpos(Curses.lines - 1, 0)
                Curses.addstr("Missing total page count from response!")
                Curses.refresh
                nil
            end
        end

        # Get products from data
        def get_products_from_data(data)
            products_data = data["products"]
            unless products_data.is_a?(Array)
                debug_log("Products key missing or not array in payload: #{data.keys}")
                return
            end

            products_data.each do |product|
                customer_returns = product["customerReturnsInfo"]
                unless customer_returns.is_a?(Hash)
                    debug_log("Skipping product without customerReturnsInfo: #{product['name']}")
                    next
                end

                id = customer_returns["id"]
                if id.nil?
                    debug_log("Skipping product with missing id: #{product['name']}")
                    next
                end

                @products << {
                    id: id,
                    name: product["name"],
                    description: product["descriptionShort"],
                    return_info: customer_returns["product_extra_info"],
                    price: customer_returns["price_with_tax"],
                    original_price: product.dig("price", "current"),
                    condition: customer_returns["condition"]
                }
                debug_log("Stored product #{id} (#{product['name']})")
            end
        end

        def perform_request(uri)
            request = Net::HTTP::Get.new(uri, HEADERS)
            build_http_client(uri).request(request)
        end

        def build_http_client(uri)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            http.cert_store = OpenSSL::X509::Store.new.tap { |store| store.set_default_paths }

            if ssl_verification_disabled?
                http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                log_insecure_ssl_warning unless @insecure_ssl_warning_logged
            else
                http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            end

            http
        end

        def ssl_verification_disabled?
            ENV.fetch(SSL_SKIP_ENV, "").strip == "1"
        end

        def log(level, message)
            path = case level
            when :error
                get_error_log_path
            else
                get_debug_log_path
            end

            FileUtils.mkdir_p(File.dirname(path))
            File.open(path, "a") do |file|
                file.puts("[#{Time.now.iso8601}] #{message}")
            end
        rescue StandardError
            # Ignore logging errors to avoid impacting the main flow
        end

        def log_insecure_ssl_warning
            warning = "SSL verification disabled (#{SSL_SKIP_ENV}=1). Connection is insecure."
            log(:error, warning)
            log(:debug, warning)
            @insecure_ssl_warning_logged = true
        end

        def debug_log(message)
            log(:debug, message)
        end

        def error_log(message)
            log(:error, message)
        end
    end
end
