module Config
    @ui_bottom_lines = 2
    @max_lines = 2
    @max_cols = 2

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