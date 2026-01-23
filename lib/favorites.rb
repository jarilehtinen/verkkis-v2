module Verkkis
    class Favorites
        SNAPSHOT_KEYS = %w[id name description price original_price condition].freeze

        attr_reader :favorites

        # Initialize
        def initialize
            @favorites = nil
        end

        # Get file path
        def get_file_path
            File.join(File.expand_path("..", __dir__), ".data/favorites.json")
        end

        # Get the favorites list located in .data/favorites.json
        def get_favorites(_available_products = nil)
            load_favorites.map { |entry| entry['id'] }
        end

        def resolved_favorite_products(available_products)
            entries = load_favorites
            indexed = index_products_by_id(available_products)

            entries.map do |entry|
                indexed[entry['id']] || build_placeholder(entry)
            end
        end

        # Save data
        def save_data
            @favorites ||= []
            File.write(get_file_path, JSON.pretty_generate(@favorites))
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error while saving data: #{e.message}")
            Curses.refresh
            exit
        end

        # Favorite product
        def favorite_product(product_or_id)
            id, snapshot = extract_id_and_snapshot(product_or_id)
            return unless id

            entries = load_favorites
            existing_index = entries.index { |entry| entry['id'] == id }

            if existing_index
                entries.delete_at(existing_index)
                @favorites = entries
                save_data
                return
            end

            entry = { 'id' => id }
            entry['snapshot'] = snapshot if snapshot && !snapshot.empty?
            entries << entry
            @favorites = entries
            save_data
        end

        private

        def load_favorites
            return @favorites if @favorites.is_a?(Array)

            file_path = get_file_path
            favorites = if File.exist?(file_path)
                JSON.parse(File.read(file_path))
            else
                []
            end

            @favorites = normalize_entries(favorites)
        end

        def normalize_entries(raw_entries)
            Array(raw_entries).map do |item|
                case item
                when Hash
                    id = normalize_single_id(item['id'] || item[:id])
                    next unless id

                    snapshot = normalize_snapshot(item['snapshot'] || item[:snapshot])
                    normalized = { 'id' => id }
                    normalized['snapshot'] = snapshot if snapshot && !snapshot.empty?
                    normalized
                else
                    id = normalize_single_id(item)
                    id ? { 'id' => id } : nil
                end
            end.compact
        end

        def normalize_snapshot(snapshot)
            return nil unless snapshot.is_a?(Hash)

            snapshot.each_with_object({}) do |(key, value), memo|
                key_str = key.to_s
                next unless SNAPSHOT_KEYS.include?(key_str)
                memo[key_str] = value
            end.tap do |result|
                return nil if result.empty?
            end
        end

        def normalize_single_id(identifier)
            return nil if identifier.nil?

            if identifier.is_a?(String)
                return nil unless identifier.match?(/\A\d+\z/)
                identifier.to_i
            elsif identifier.respond_to?(:to_i)
                identifier.to_i
            else
                nil
            end
        end

        def extract_id_and_snapshot(product_or_id)
            if product_or_id.is_a?(Hash)
                id = normalize_single_id(product_or_id['id'] || product_or_id[:id])
                snapshot = snapshot_from_product(product_or_id)
                [id, snapshot]
            else
                [normalize_single_id(product_or_id), nil]
            end
        end

        def snapshot_from_product(product)
            return nil unless product.is_a?(Hash)

            SNAPSHOT_KEYS.each_with_object({}) do |key, memo|
                value = product[key] || product[key.to_sym]
                next if value.nil? || (value.respond_to?(:empty?) && value.empty?)
                memo[key] = value
            end.tap do |result|
                return nil if result.empty?
            end
        end

        def index_products_by_id(products)
            Array(products).each_with_object({}) do |product, memo|
                next unless product.is_a?(Hash)

                identifier = product['id'] || product[:id]
                id = normalize_single_id(identifier)
                next unless id

                memo[id] = product
            end
        end

        def build_placeholder(entry)
            snapshot = entry['snapshot'] || {}
            id = entry['id']
            name = snapshot['name']
            name = "Poistunut tuote ##{id}" if name.to_s.strip.empty?
            description = snapshot['description']
            description = "Tuote ei ole enää saatavilla." if description.to_s.strip.empty?

            {
                'id' => id,
                'name' => name,
                'description' => description,
                'price' => snapshot['price'],
                'original_price' => snapshot['original_price'],
                'condition' => snapshot['condition'],
                'missing_favorite' => true
            }
        end
    end

    class ManufacturerFavorites
        attr_reader :favorites

        def initialize
            @favorites = nil
        end

        def get_file_path
            File.join(File.expand_path("..", __dir__), ".data/manufacturer_favorites.json")
        end

        def get_favorites
            load_favorites.dup
        end

        def favorite_manufacturer(name)
            normalized = normalize_name(name)
            return unless normalized

            entries = load_favorites
            if entries.include?(normalized)
                entries.delete(normalized)
            else
                entries << normalized
            end

            @favorites = entries
            save_data
        end

        private

        def load_favorites
            return @favorites if @favorites.is_a?(Array)

            file_path = get_file_path
            favorites = if File.exist?(file_path)
                JSON.parse(File.read(file_path))
            else
                []
            end

            @favorites = normalize_entries(favorites)
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error while reading manufacturer favorites: #{e.message}")
            Curses.refresh
            exit
        end

        def save_data
            @favorites ||= []
            File.write(get_file_path, JSON.pretty_generate(@favorites))
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error while saving manufacturer favorites: #{e.message}")
            Curses.refresh
            exit
        end

        def normalize_entries(raw_entries)
            Array(raw_entries).map { |item| normalize_name(item) }.compact.uniq
        end

        def normalize_name(name)
            return nil unless name

            normalized = name.to_s.strip
            return nil if normalized.empty?

            normalized
        end
    end
end
