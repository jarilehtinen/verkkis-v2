module Verkkis
    class Manufacturers
        def list(ui, products, manufacturer_favorites = nil)
            manufacturers = products.map { |product| manufacturer_from_name(product['name']) }.compact.uniq.sort
            return [nil, nil] if manufacturers.empty?

            ui.draw("Valmistajat")

            current_manufacturer = 0
            win = nil
            window_height = Config.max_lines - Config.ui_bottom_lines - 2
            window_height = 1 if window_height < 1
            window_width = Config.max_cols - 3
            max_rows = window_height
            max_rows = 1 if max_rows < 1
            col_padding = 2
            marker_width = 2
            max_name_length = manufacturers.map(&:length).max || 0
            col_width = [max_name_length + marker_width, 20].max
            max_col_width = [window_width - 2, 1].max
            col_width = [col_width, max_col_width].min
            columns_per_page = [((window_width - 2) / (col_width + col_padding)), 1].max
            favorite_set = {}
            refresh_favorites = lambda do
                favorites = manufacturer_favorites ? manufacturer_favorites.get_favorites : []
                favorite_set = favorites.each_with_object({}) do |name, memo|
                    memo[name] = true
                end
            end
            refresh_favorites.call

            win = Curses::Window.new(window_height, window_width, 1, 1)
            win.erase

            loop do
                win.erase
                current_col = current_manufacturer / max_rows
                start_col = [current_col - (columns_per_page - 1), 0].max

                manufacturers.each_with_index do |manufacturer, index|
                    row = index % max_rows
                    col = index / max_rows
                    next if col < start_col
                    break if col >= start_col + columns_per_page
                    x_pos = 1 + (col - start_col) * (col_width + col_padding)

                    color = (index == current_manufacturer) ? 2 : 1
                    star_color = (index == current_manufacturer) ? 8 : 7
                    favorite = favorite_set[manufacturer]
                    prefix_width = favorite ? marker_width : 0
                    name_width = [col_width - prefix_width, 0].max
                    truncated_name = manufacturer
                    if truncated_name.length > name_width
                        truncated_name = if name_width > 3
                            truncated_name[0, name_width - 3] + "..."
                        else
                            truncated_name[0, name_width]
                        end
                    end

                    win.setpos(row, x_pos)
                    if favorite
                        win.attron(Curses.color_pair(star_color)) do
                            win.addstr("★")
                        end
                        win.attron(Curses.color_pair(color)) do
                            win.addstr(" ")
                            win.addstr(truncated_name.ljust(name_width))
                        end
                    else
                        win.attron(Curses.color_pair(color)) do
                            win.addstr(truncated_name.ljust(name_width))
                        end
                    end
                end

                win.refresh

                case (ch = Curses.getch)
                    when Curses::Key::DOWN
                        current_manufacturer += 1 if current_manufacturer < manufacturers.length - 1

                    when Curses::Key::UP
                        current_manufacturer -= 1 if current_manufacturer > 0

                    when Curses::Key::LEFT
                        current_manufacturer -= max_rows
                        current_manufacturer = 0 if current_manufacturer.negative?

                    when Curses::Key::RIGHT
                        current_manufacturer += max_rows
                        current_manufacturer = manufacturers.length - 1 if current_manufacturer >= manufacturers.length

                    when ".", "f", "F"
                        if manufacturer_favorites
                            selected = manufacturers[current_manufacturer]
                            manufacturer_favorites.favorite_manufacturer(selected) if selected
                            refresh_favorites.call
                        end

                    when 10, Curses::Key::ENTER
                        selected = manufacturers[current_manufacturer]
                        win.clear
                        win.refresh
                        win.close
                        win = nil
                        return [selected, nil]

                    when "q", 27
                        return [nil, nil]

                    else
                        return [nil, ch]
                end
            end
        ensure
            if win
                win.clear
                win.refresh
                win.close
            end
        end

        private

        def manufacturer_from_name(name)
            return nil unless name
            name.split(/\s/).first
        end
    end
end
