require 'set'

module Verkkis
    class Favorites
        attr_reader :favorites

        # Initialize
        def initialize
            @favorites = []
        end

        # Get file path
        def get_file_path
            File.join(File.expand_path("..", __dir__), ".data/favorites.json")
        end

        # Get the favorites list located in .data/favorites.json
        def get_favorites(available_products = nil)
            file_path = get_file_path

            favorites = if File.exist?(file_path)
                JSON.parse(File.read(file_path))
            else
                []
            end

            favorites = normalize_ids(favorites)
            favorites = remove_missing_favorites(favorites, available_products)

            @favorites = favorites
            favorites
        end

        # Save data
        def save_data
            File.write(get_file_path, JSON.pretty_generate(@favorites))
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error while saving data: #{e.message}")
            Curses.refresh
            exit
        end

        # Favorite product
        def favorite_product(id)
            id = normalize_single_id(id)
            return unless id

            # Get favorites
            @favorites = get_favorites

            # Remove product if already in favorites
            if @favorites.include?(id)
                @favorites.delete(id)
                save_data
                return
            end

            # Add the product to the favorites list located in .data/favorites.json
            @favorites << id

            # Save the updated favorites list
            save_data
        end

        private

        def normalize_ids(ids)
            Array(ids).map do |item|
                case item
                when Hash
                    normalize_single_id(item['id'] || item[:id])
                else
                    normalize_single_id(item)
                end
            end.compact
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

        def remove_missing_favorites(favorites, available_products)
            return favorites if available_products.nil?

            valid_ids = normalize_ids(available_products)
            return favorites if valid_ids.empty?

            valid_id_set = valid_ids.to_set
            filtered_favorites = favorites.select { |fav_id| valid_id_set.include?(fav_id) }

            if filtered_favorites.length != favorites.length
                @favorites = filtered_favorites
                save_data
            end

            filtered_favorites
        end
    end
end
