module Verkkis
    class Manufacturers
        def list(ui, products)
            ui.draw
            ui.title("Valmistajat")

            current_manufacturer = 0

            win = Curses::Window.new(Config.max_lines - Config.ui_bottom_lines - 1, Config.max_cols - 3, 1, 1)
            win.erase

            loop do
                # Manufacturer is usually the first word in the product name
                # get all unique manufacturers
                manufacturers = products.map { |product| product['name'].split(" ")[0] }.uniq

                # Sort alphabetically
                manufacturers.sort!

                y = 0
                x_pos = 1
                manufacturer_i = 0
                col_width = 20
                col_padding = 1

                manufacturers.each_with_index do |manufacturer, i|
                    color = (manufacturer_i == current_manufacturer) ? 2 : 1

                    win.attron(Curses.color_pair(color)) do
                        text = "#{manufacturer}";

                        if (text.length > col_width)
                            text = text[0, col_width - 3] + "..."
                        end

                        win.setpos(y, x_pos)
                        win.addstr(text)

                        if (text.length < col_width)
                            win.setpos(y, x_pos + text.length)
                            win.addstr(" " * (col_width - text.length))
                        end
                    end

                    y += 1
                    manufacturer_i += 1

                    # If Config.max_lines is exceeded, move to next column
                    if y >= Config.max_lines - Config.ui_bottom_lines - 1
                        x_pos += col_width + col_padding
                        y = 0
                    end

                    if x_pos + col_width >= Config.max_cols
                        break
                    end
                end

                win.refresh

                case Curses.getch
                    when Curses::Key::DOWN
                        current_manufacturer += 1 if current_manufacturer < manufacturers.length - 1

                    when Curses::Key::UP
                        current_manufacturer -= 1 if current_manufacturer > 0

                    when Curses::Key::LEFT
                        current_manufacturer -= Config.max_lines - Config.ui_bottom_lines - 1

                    when Curses::Key::RIGHT
                        current_manufacturer += Config.max_lines - Config.ui_bottom_lines - 1

                    when "q", 27
                        break
                end
            end
        end
    end
end