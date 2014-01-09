class DungeonLevel
  def initialize(rows, cols)
    @cells = init_random_level rows, cols
  end
  attr_accessor :cells

  def transparent?(col, row)
    @cells[row][col] != '#'
  end

  def walkable?(col, row)
    @cells[row][col] == '.'
  end

  def init_random_level(rows, cols)
    level = []
    rows.times do |row|
      new_row = []
      cols.times do |col|
        if GlobalGameState::PRNG.rand > 0.8
          new_row.push "#"
        else
          new_row.push "."
        end
      end
      level.push new_row
    end
    level
  end
end

