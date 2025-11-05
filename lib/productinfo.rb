module Verkkis
    class ProductInfo
        def view(ui, product, price_history)
            previous_title = ui.current_title
            ui.draw(product['name'])
            price_changes = normalize_price_history(price_history)

            win = Curses::Window.new(Config.max_lines - Config.ui_bottom_lines - 1, Config.max_cols - 3, 1, 1)

            loop do
                win.erase

                win.attron(Curses.color_pair(5) | Curses::A_BOLD) do
                    win.setpos(1, 3)
                    win.addstr("#{product['name']}")
                end

                condition_row = nil

                win.attron(Curses.color_pair(5)) do
                    description_start_y = 3
                    description_start_x = 3
                    description_width = [win.maxx - description_start_x - 1, 1].max
                    description_lines = wrap_text_to_width(product['description'], description_width)

                    unless description_lines.empty?
                        win.setpos(description_start_y, description_start_x)
                        indent = " " * description_start_x
                        win.addstr(description_lines.join("\n" + indent))
                    end

                    lines_written = description_lines.length
                    price_row_default = description_start_y + 3
                    price_row = [price_row_default, description_start_y + lines_written + 1].max

                    win.setpos(price_row, description_start_x)
                    text = "Hinta:  #{product['price']} €"

                    if product['original_price']
                        text += " (#{product['original_price']} €)"
                    end

                    win.addstr(text)
                    condition_row = price_row + 1
                    win.setpos(condition_row, description_start_x)
                    win.addstr("Kunto:  #{product['condition']}")
                end

                condition_row ||= 7
                link_row = condition_row + 2

                win.attron(Curses.color_pair(6)) do
                    win.setpos(link_row, 3)
                    win.addstr("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")
                end

                chart_top = link_row + 2
                render_price_history_chart(win, price_changes, chart_top: chart_top)
                win.refresh

                key = win.getch

                if key == "o"
                    Launchy.open("https://www.verkkokauppa.com/fi/outlet/yksittaiskappaleet/#{product['id']}")
                elsif key == "q" || key == 27 || key == Curses::Key::LEFT
                    break
                end
            end

            restored_title = previous_title.to_s.empty? ? "Uusimmat tuotteet" : previous_title
            ui.draw(restored_title)
        end

        private

        def normalize_price_history(history)
            return [] unless history.is_a?(Array)

            sorted = history.map do |entry|
                price = entry['price'] || entry[:price]
                date = entry['date'] || entry[:date]
                next if price.nil? || date.nil?

                { price: price.to_f, date: date.to_i }
            end.compact.sort_by { |entry| entry[:date] }

            sorted.each_with_object([]) do |entry, result|
                if result.empty? || result.last[:price] != entry[:price]
                    result << entry
                else
                    # Replace duplicate price with the latest timestamp to keep timeline accurate
                    result[-1] = entry
                end
            end
        end

        def render_price_history_chart(win, price_changes, chart_top: 11)
            chart_left = 4
            chart_width = Config.max_cols - chart_left - 6
            available_height = Config.max_lines - Config.ui_bottom_lines - chart_top - 4

            return if chart_width < 2 || available_height < 1

            max_chart_height = 8
            chart_height = [available_height, max_chart_height].min
            chart_height = [chart_height, 3].max if available_height >= 3
            chart_height = [chart_height, 1].max

            axis_row = chart_top + chart_height
            labels_row = axis_row + 1
            legend_row = labels_row + 1

            clear_chart_area(win, chart_top - 1, legend_row, chart_left - 2) # allow header clearing

            if price_changes.length <= 1
                win.attron(Curses.color_pair(5)) do
                    win.setpos(chart_top, chart_left)
                    win.addstr(price_changes.empty? ? "Hintahistoria ei ole saatavilla." : "Hintamuutoksia ei ole.")
                end
                return
            end

            chart_title = "Hintakehitys (#{format_price(price_changes.first[:price])} € → #{format_price(price_changes.last[:price])} €)"
            win.attron(Curses.color_pair(5)) do
                win.setpos(chart_top - 1, chart_left)
                win.addstr(chart_title[0, chart_width])
            end

            min_price = price_changes.map { |entry| entry[:price] }.min
            max_price = price_changes.map { |entry| entry[:price] }.max
            price_range = [max_price - min_price, 1.0].max

            points = price_changes.each_with_index.map do |entry, index|
                x = if price_changes.length == 1
                    chart_width / 2
                else
                    ((index * (chart_width - 1)).to_f / (price_changes.length - 1)).round
                end

                ratio = (entry[:price] - min_price) / price_range
                y = chart_height - 1 - (ratio * (chart_height - 1)).round
                y = [[y, 0].max, chart_height - 1].min

                {
                    x: x,
                    y: y,
                    price: entry[:price],
                    date: entry[:date],
                    label: Time.at(entry[:date]).strftime("%d.%m")
                }
            end

            grid = Array.new(chart_height) { Array.new(chart_width, " ") }

            points.each_cons(2) do |a, b|
                x1, y1 = a.values_at(:x, :y)
                x2, y2 = b.values_at(:x, :y)

                if x1 == x2
                    y_min, y_max = [y1, y2].minmax
                    (y_min..y_max).each do |y|
                        grid[y][x1] = grid[y][x1] == " " ? "|" : grid[y][x1]
                    end
                    next
                end

                x_range = x1 < x2 ? (x1..x2) : (x2..x1)
                slope_char = if y2 > y1
                    "\\"
                elsif y2 < y1
                    "/"
                else
                    "-"
                end

                x_range.each do |x|
                    t = (x - x1).to_f / (x2 - x1)
                    y = (y1 + t * (y2 - y1)).round
                    y = [[y, 0].max, chart_height - 1].min
                    grid[y][x] = slope_char if grid[y][x] == " "
                end
            end

            points.each_with_index do |point, index|
                char = index == points.length - 1 ? "@" : "o"
                grid[point[:y]][point[:x]] = char
            end

            draw_axes(win, chart_left, chart_top, chart_width, chart_height)
            draw_grid(win, grid, chart_left, chart_top)
            draw_axis_labels(win, points, min_price, max_price, chart_left, chart_top, chart_width, chart_height, axis_row, labels_row)
            draw_legend(win, legend_row, chart_left, chart_width)
        end

        def wrap_text_to_width(text, width)
            width = [width, 1].max

            text.to_s.split(/\r?\n/, -1).each_with_object([]) do |paragraph, lines|
                if paragraph.strip.empty?
                    lines << ""
                    next
                end

                current_line = ""
                paragraph.split(/\s+/).each do |word|
                    next if word.empty?

                    if current_line.empty?
                        current_line = word
                    elsif current_line.length + 1 + word.length <= width
                        current_line << " " << word
                    else
                        lines << current_line
                        current_line = word
                    end
                end

                lines << current_line unless current_line.empty?
            end
        end

        def clear_chart_area(win, top_row, bottom_row, left_col)
            max_row = win.maxy - 1

            (top_row..bottom_row).each do |row|
                next if row.negative? || row > max_row

                win.setpos(row, [left_col, 0].max)
                win.clrtoeol
            end
        end

        def draw_axes(win, left, top, width, height)
            height.times do |row|
                win.setpos(top + row, left - 1)
                win.addstr("|")
            end

            win.setpos(top + height, left - 1)
            win.addstr("+" + "-" * width)
        end

        def draw_grid(win, grid, left, top)
            grid.each_with_index do |row, index|
                win.setpos(top + index, left)
                win.addstr(row.join)
            end
        end

        def draw_axis_labels(win, points, min_price, max_price, left, top, width, height, axis_row, labels_row)
            win.attron(Curses.color_pair(5)) do
                max_label = "#{format_price(max_price)} €"
                min_label = "#{format_price(min_price)} €"

                win.setpos(top, left + width + 1)
                win.addstr(max_label)

                win.setpos(top + height - 1, left + width + 1)
                win.addstr(min_label)
            end

            points.each do |point|
                label_col = left + point[:x]

                win.setpos(axis_row, label_col)
                win.addstr("|")

                next_label = point[:label]
                next if next_label.nil? || next_label.empty?

                label_start = label_col - (next_label.length / 2)
                label_start = left if label_start < left
                label_start = left + width - next_label.length if label_start + next_label.length > left + width

                win.setpos(labels_row, label_start)
                win.addstr(next_label)
            end
        end

        def draw_legend(win, legend_row, left, width)
            legend_text = "@ = nykyinen hinta"
            win.attron(Curses.color_pair(5)) do
                win.setpos(legend_row, left)
                win.addstr(legend_text[0, width])
            end
        end

        def format_price(price)
            (price.round(2) % 1).zero? ? price.to_i.to_s : format('%.2f', price)
        end
    end
end
