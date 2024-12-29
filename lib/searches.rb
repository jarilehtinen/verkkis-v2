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

        # List searches
        def list(ui)
            ui.draw("Tallennetut haut")

            win = Curses::Window.new(Config.max_lines - Config.ui_bottom_lines - 1, Config.max_cols - 3, 1, 1)
            win.erase

            searches = get_searches
            selected_search = 0

            loop do
                if searches
                    searches.each_with_index do |search_term, i|
                        win.attron(Curses.color_pair(selected_search == i ? 2 : 1)) do
                            text = "#{search_term}" + (" " * (Config.max_cols - 4 - search_term.length))
                            win.setpos(i, 1)
                            win.addstr(text)
                        end
                    end
                end

                win.refresh

                case Curses.getch
                    # Down: move down
                    when Curses::Key::DOWN
                        selected_search += 1 if selected_search < searches.length - 1

                    # Up: move up
                    when Curses::Key::UP
                        selected_search -= 1 if selected_search > 0

                    # Delete: delete search
                    when "d", 127
                        index = selected_search

                        if index >= 0 && index < searches.length
                            delete_search(searches[index])
                            searches = get_searches
                            selected_search = selected_search - 1
                            ui.draw
                        end

                    # Enter: search products with given term
                    when 10
                        ui.draw("Haku: #{searches[selected_search]}")
                        return searches[selected_search]

                    # Q: quit
                    when "q", 27
                        break
                end
            end
        end
    end
end
