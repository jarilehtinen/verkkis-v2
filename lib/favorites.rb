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
        def get_favorites
            file_path = get_file_path

            if File.exist?(file_path)
                JSON.parse(File.read(file_path))
            else
                []
            end
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
    end
end
