module Verkkis
    class Searches
        # Initialize
        def initialize
            @searches = []
        end

        # Get file path
        def get_file_path
            Verkkis.data_path("searches.json")
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
        def save_search(ui, search_string)
            # Check if search_string is empty
            return if search_string.empty?

            @searches = get_searches
            @searches << search_string
            @searches.uniq!
            File.write(get_file_path, JSON.pretty_generate(@searches))
            ui.draw("Haku \"" + search_string + "\" tallennettu")
        end

        # Save searches
        def save_searches
            File.write(get_file_path, JSON.pretty_generate(@searches))
        rescue StandardError => e
            Verkkis.abort_with_message("Error while saving search: #{e.message}")
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

            window_height = Config.max_lines - Config.ui_bottom_lines - 2
            window_height = 1 if window_height < 1
            win = Curses::Window.new(window_height, Config.max_cols - 3, 1, 1)
            win.erase

            searches = get_searches
            selected_search = 0

            delete_keys = ["d", 127]
            delete_keys << Curses::Key::BACKSPACE if defined?(Curses::Key::BACKSPACE)
            delete_keys << Curses::Key::DC if defined?(Curses::Key::DC)
            enter_keys = [10]
            enter_keys << Curses::Key::ENTER if defined?(Curses::Key::ENTER)

            loop do
                win.erase

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

                input = Curses.getch
                next if input.nil?

                case input
                    # Down: move down
                    when Curses::Key::DOWN
                        selected_search += 1 if selected_search < searches.length - 1

                    # Up: move up
                    when Curses::Key::UP
                        selected_search -= 1 if selected_search > 0

                    # Delete: delete search
                    when *delete_keys
                        index = selected_search

                        if index >= 0 && index < searches.length
                            delete_search(searches[index])
                            searches = get_searches
                            if searches.empty?
                                selected_search = 0
                            else
                                selected_search = [index, searches.length - 1].min
                            end
                            ui.draw('Tallennetut haut')
                        end

                    # Enter: search products with given term
                    when *enter_keys
                        next if searches.empty?
                        ui.draw("Haku: #{searches[selected_search]}")
                        return [searches[selected_search], nil]

                    # Q: quit
                    when "q", 27
                        return [nil, nil]

                    else
                        return [nil, input]
                end
            end

            [nil, nil]
        end
    end
end
