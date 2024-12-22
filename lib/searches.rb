module Verkkis
    class Searches
        # Initialize
        def initialize
            @searches = []
        end

        # Get file path
        def get_file_path
            File.join(File.expand_path("..", __dir__), ".data/searches.json")
        end

        # Get the searches list located in .data/searches.json
        def get_searches
            file_path = get_file_path

            if File.exist?(file_path)
                JSON.parse(File.read(file_path))
            else
                []
            end
        end

        # Save search
        def save_search(search_string)
            # Check if search_string is empty
            return if search_string.empty?

            @searches = get_searches
            @searches << search_string
            @searches.uniq!
            File.write(get_file_path, JSON.pretty_generate(@searches))
        end

        # Save searches
        def save_searches
            File.write(get_file_path, JSON.pretty_generate(@searches))
        rescue StandardError => e
            Curses.setpos(Curses.lines - 1, 0)
            Curses.addstr("Error while saving search: #{e.message}")
            Curses.refresh
            exit
        end

        # Delete search
        def delete_search(search_string)
            @searches = get_searches
            @searches.delete(search_string)
            save_searches
        end
    end
end
