module Config
    @help_rows = [
        [
            { key: "1", label: "Uudet" },
            { key: "2", label: "Haussa" },
            { key: "3", label: "Suosikit" },
            { key: "4", label: "A-Ö" },
            { key: "5", label: "Hinta" },
            { key: "6", label: "Eniten alennusta" },
            { key: "H", label: "Tallennetut haut" },
            { key: "V", label: "Valmistajat" }
        ],
        [
            { key: "E", label: "Etsi" },
            { key: ".", label: "Suosikki" },
            { key: "A", label: "Avaa tuotesivu" },
            { key: "P", label: "Päivitä" },
            { key: "Q", label: "Lopeta" }
        ]
    ]

    @ui_bottom_lines = @help_rows.length
    @max_lines = 2
    @max_cols = 2

    def self.help_rows
        @help_rows
    end

    def self.help_rows=(value)
        @help_rows = value
        @ui_bottom_lines = value.length if value.respond_to?(:length)
    end

    def self.ui_bottom_lines
        @ui_bottom_lines
    end

    def self.ui_bottom_lines=(value)
        @ui_bottom_lines = value
    end

    def self.max_lines
        @max_lines
    end

    def self.max_lines=(value)
        @max_lines = value
    end

    def self.max_cols
        @max_cols
    end

    def self.max_cols=(value)
        @max_cols = value
    end
end
