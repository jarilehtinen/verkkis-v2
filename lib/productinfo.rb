module Verkkis
    class ProductInfo
        def view(ui, product)
            ui.draw(product['name'])

            win = Curses::Window.new(Config.max_lines - Config.ui_bottom_lines - 1, Config.max_cols - 3, 1, 1)
            win.erase

            loop do
                win.attron(Curses.color_pair(5) | Curses::A_BOLD) do
                    win.setpos(1, 3)
                    win.addstr("#{product['name']}")
                end

                win.attron(Curses.color_pair(5)) do
                    win.setpos(3, 3)
                    win.addstr("#{product['description']}")
                    win.setpos(6, 3)
                    text = "Hinta:  #{product['price']} €"

                    if product['original_price']
                        text += " (#{product['original_price']} €)"
                    end

                    win.addstr(text)
                    win.setpos(7, 3)
                    win.addstr("Kunto:  #{product['condition']}")
                end

                win.attron(Curses.color_pair(6)) do
                    win.setpos(9, 3)
                    win.addstr("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")
                end

                win.refresh

                key = win.getch

                if key == "o"
                    Launchy.open("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")
                elsif key == "q" || key == 27 || key == Curses::Key::LEFT
                    break
                end
            end

            ui.draw("")
        end
    end
end