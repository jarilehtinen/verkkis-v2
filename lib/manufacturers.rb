module Verkkis
    class Manufacturers
        def list(ui, products)
            manufacturers = products.map { |product| manufacturer_from_name(product['name']) }.compact.uniq.sort
            return nil if manufacturers.empty?

            ui.draw("Valmistajat")

            current_manufacturer = 0
            win = nil
            window_height = Config.max_lines - Config.ui_bottom_lines - 2
            window_height = 1 if window_height < 1
            window_width = Config.max_cols - 3
            max_rows = window_height
            max_rows = 1 if max_rows < 1
            col_padding = 2
            col_width = [manufacturers.map(&:length).max || 0, 20].max
            max_col_width = [window_width - 2, 1].max
            col_width = [col_width, max_col_width].min

            win = Curses::Window.new(window_height, window_width, 1, 1)
            win.erase

            loop do
                win.erase

                manufacturers.each_with_index do |manufacturer, index|
                    row = index % max_rows
                    col = index / max_rows
                    x_pos = 1 + col * (col_width + col_padding)
                    break if x_pos + col_width >= window_width

                    color = (index == current_manufacturer) ? 2 : 1

                    win.attron(Curses.color_pair(color)) do
                        text = manufacturer
                        if text.length > col_width
                            text = if col_width > 3
                                text[0, col_width - 3] + "..."
                            else
                                text[0, col_width]
                            end
                        end

                        win.setpos(row, x_pos)
                        win.addstr(text.ljust(col_width))
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

                    when 10, Curses::Key::ENTER
                        selected = manufacturers[current_manufacturer]
                        win.clear
                        win.refresh
                        win.close
                        win = nil
                        return selected

                    when "q", 27
                        break
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
