module Verkkis
    class UI
        last_title = ""

        def draw(title_text)
            box(
                Config.max_lines - Config.ui_bottom_lines,
                Config.max_cols,
                0,
                0
            )

            if title_text != ""
                title(title_text)
            else
                title(@last_title)
            end

            help()

            Curses.refresh
        end

        # Draw box
        def box(h, w, y, x)
            # Set color
            Curses.attron(Curses.color_pair(1)) do
                # Top left corner
                Curses.setpos(y, x)
                Curses.addstr("┌")

                # Top right corner
                Curses.setpos(y, x + w - 1)
                Curses.addstr("┐")

                # Bottom left corner
                Curses.setpos(y + h, x)
                Curses.addstr("└")

                # Bottom right corner
                Curses.setpos(y + h, w + x - 1)
                Curses.addstr("┘")

                # Top horizontal line
                Curses.setpos(y, x + 1)
                Curses.addstr("─" * (w - 2))

                # Bottom horizontal line
                Curses.setpos(y + h, x + 1)
                Curses.addstr("─" * (w - 2))

                # Draw vertical lines
                (y + 1..(y + h - 1)).each do |this_y|
                    Curses.setpos(this_y, x)
                    Curses.addstr("│")
                    Curses.setpos(this_y, x + w - 1)
                    Curses.addstr("│")
                end

                Curses.refresh
            end

        end

        # Print title centered
        def title(title)
            if title == ""
                return
            end

            @last_title = title
            title = " #{title} "
            Curses.setpos(0, (Config.max_cols / 2) - title.length / 2)
            Curses.attron(Curses.color_pair(2))
            Curses.addstr(title)
            Curses.attroff(Curses.color_pair(2))
            Curses.refresh
        end

        # Print help
        def help()
            Curses.setpos(Config.max_lines - 1, 0)
            Curses.clrtoeol

            texts = {
                "1": "Uusimmat",
                "2": "Haussa",
                "3": "Suosikit",
                "4": "A-Ö",
                "5": "Hinta",
                "E": "Etsi",
                "T": "Tallenna haku",
                "H": "Tallennetut haut",
                ".": "Suosikki",
                "O": "Avaa selaimeen",
                "P": "Päivitä",
                "Q": "Lopeta"
            }

            y_pos = Config.max_lines - 1
            text_pos = 1

            texts.each do |id, text|
                Curses.attron(Curses.color_pair(2)) do
                    Curses.setpos(y_pos, text_pos)
                    text_pos += id.length + 3
                    Curses.addstr(" #{id.to_s} ")
                end

                Curses.attron(Curses.color_pair(1)) do
                    Curses.setpos(y_pos, text_pos)
                    text_pos += text.length + 1
                    Curses.addstr(text)
                end
            end

            Curses.refresh
        end
    end
end