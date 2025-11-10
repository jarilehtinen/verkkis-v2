module Verkkis
    class UI
        last_title = ""

        def current_title
            @last_title
        end

        def draw(title_text)
            box_height = Config.max_lines - Config.ui_bottom_lines - 1
            box_height = 0 if box_height < 0
            box(
                box_height,
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
            bottom_start = Config.max_lines - Config.ui_bottom_lines
            bottom_start = 0 if bottom_start < 0
            bottom_start.upto(Config.max_lines - 1) do |line|
                Curses.setpos(line, 0)
                Curses.clrtoeol
            end

            lines = Config.help_rows || []
            lines = lines.first(Config.ui_bottom_lines)

            lines.each_with_index do |line_entries, index|
                y_pos = bottom_start + index
                text_pos = 1

                line_entries.each do |entry|
                    key = entry[:key] || entry["key"]
                    text = entry[:label] || entry["label"]
                    next if key.nil? || text.nil?

                    id_str = " #{key} "
                    Curses.attron(Curses.color_pair(2)) do
                        Curses.setpos(y_pos, text_pos)
                        Curses.addstr(id_str)
                    end

                    text_pos += id_str.length + 1

                    Curses.attron(Curses.color_pair(1)) do
                        Curses.setpos(y_pos, text_pos)
                        Curses.addstr(text)
                    end

                    text_pos += text.length + 1
                end
            end

            Curses.refresh
        end
    end
end
