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

  # FIXME? does this belong here?
  def actor_at_location(location)
    GlobalGameState::ACTORS.values.each do |actor|
      actor_location = { x: actor.pos_x, y: actor.pos_y }
      return actor if actor_location == location
    end
    return nil
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

