require 'curses'

module Verkkis
    # Hakemisto johon kaikki sovelluksen tila tallennetaan (.data projektin juuressa)
    DATA_DIR = File.join(File.expand_path("..", __dir__), ".data")

    # Palauttaa polun .data-hakemiston tiedostoon
    def self.data_path(filename)
        File.join(DATA_DIR, filename)
    end

    # Näyttää viestin ruudun alareunassa (ei keskeytä suoritusta)
    def self.show_message(message)
        Curses.setpos(Curses.lines - 1, 0)
        Curses.addstr(message)
        Curses.refresh
    end

    # Näyttää viestin ja lopettaa ohjelman
    def self.abort_with_message(message)
        show_message(message)
        exit
    end
end
