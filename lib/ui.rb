module Verkkis
    class UI
        def draw()
            box()
            title("Verkkis")
            help()
            Curses.refresh
        end

        # Draw box
        def box()
            Curses.setpos(0, 0)

            Curses.attron(Curses.color_pair(1))
            Curses.addstr("┌")

            Curses.setpos(0, 1)
            Curses.addstr("─" * (Config.max_cols - 2))

            Curses.setpos(0, Config.max_cols - 1)
            Curses.addstr("┐")

            Curses.setpos(Config.max_lines - Config.ui_bottom_lines, 0)
            Curses.addstr("└")

            Curses.setpos(Config.max_lines - Config.ui_bottom_lines, 1)
            Curses.addstr("─" * (Config.max_cols - 2))

            Curses.setpos(Config.max_lines - Config.ui_bottom_lines, Config.max_cols - 1)
            Curses.addstr("┘")

            # Piirra pystyviivat
            (1..Config.max_lines - Config.ui_bottom_lines - 1).each do |y|
                Curses.setpos(y, 0)
                Curses.addstr("│")
                Curses.setpos(y, Config.max_cols - 1)
                Curses.addstr("│")
            end

            Curses.attroff(Curses.color_pair(1))
        end

        # Print title centered
        def title(title)
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
                q: "Lopeta",
                e: "Etsi",
                t: "Tallenna haku",
                z: "Tallennetut haut",
                l: "Haussa",
                u: "Uudet",
                a: "A-Ö",
                h: "Hinta",
                s: "Suosikit",
                ".": "Suosikki",
                i: "Tuotetiedot",
                p: "Päivitä"
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