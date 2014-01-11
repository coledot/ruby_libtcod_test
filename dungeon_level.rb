class DungeonLevel
  def initialize(rows, cols)
    @num_rows = rows
    @num_cols = cols
    @cells = init_random_level rows, cols
  end
  attr_accessor :cells

  FLOOR_CHAR = '.'
  WALL_CHAR = '#'

  def transparent?(col, row)
    return false if out_of_bounds?(col, row)
    @cells[row][col] != WALL_CHAR
  end

  def walkable?(col, row)
    return false if out_of_bounds?(col, row)
    @cells[row][col] == FLOOR_CHAR
  end

  private

  def out_of_bounds?(col, row)
    not in_bounds? col, row
  end

  def in_bounds?(col, row)
    (0 <= col && col < @num_cols) && (0 <= row && row < @num_rows)
  end

  def init_random_level(rows, cols)
    level = []
    rows.times do |row|
      new_row = []
      cols.times do |col|
        if GlobalGameState::PRNG.rand > 0.8
          new_row.push WALL_CHAR
        else
          new_row.push FLOOR_CHAR
        end
      end
      level.push new_row
    end
    level
  end
end

