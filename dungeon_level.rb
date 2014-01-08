class DungeonLevel
  def initialize(rows, cols)
    @cells = init_random_level rows, cols
  end
  attr_accessor :cells

  def transparent?(col, row)
    @cells[row][col] != '#'
  end

  def walkable?(actor, col, row)
    @cells[row][col] == '.' && (not ally_at?(actor, col, row))
  end

  def ally_at?(actor, col, row)
    other_actor = actor_at_location({x: col, y: row})
    return false unless other_actor
  
    allies = allies_of actor
    allies.include? other_actor
  end

  # FIXME? does this belong here?
  def actor_at_location(location)
    GlobalGameState::ACTORS.values.each do |actor|
      actor_location = { x: actor.pos_x, y: actor.pos_y }
      return actor if actor_location == location
    end
    return nil
  end
  
  # FIXME? does this belong here?
  def allies_of(actor)
    GlobalGameState::ACTORS.values.select{|a| a.allegiance == actor.allegiance}
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

