require 'libtcod'

class Actor
  GENERIC_ACTOR_OPTIONS = {
    sigil: '*',
    fore_color: TCOD::Color::WHITE,
    back_color: TCOD::Color::BLACK,
    x: 0,
    y: 0,
    hp: 1,
    sight_range: 8,
    name: "A faint yet distinct point of light",
    # TODO change allegiance to neutral; add an "activity" setting that defines if a creature is:
    #      sleeping, resting, hunting, pursuing, wandering, etc.
    allegiance: :player,
    player: false
  }

  def initialize(current_dlevel, options)
    options = GENERIC_ACTOR_OPTIONS.merge options
    @sigil          = options[:sigil]
    @fore_color     = options[:fore_color]
    @back_color     = options[:back_color]
    @pos_x          = options[:x]
    @pos_y          = options[:y]
    @hp             = options[:hp]
    @name           = options[:name]
    @allegiance     = options[:allegiance]
    @player         = options[:player]
    @dungeon_level  = current_dlevel
    @sight_range    = options[:sight_range]

    tcod_map.compute_fov(@pos_x, @pos_y, @sight_range, true, TCOD::FOV_BASIC)
  end
  attr_accessor :sigil, :fore_color, :back_color, :pos_x, :pos_y, :hp, :name, :allegiance

  def tcod_map
    @tcod_map ||= make_tcod_map_from_dungeon_level
  end

  def player?
    @player
  end

  # XXX nevermind the philosophical dillemmas, "should a zombie ever return true for .alive()?" etc.
  def alive?
    @hp > 0
  end

  def hurt(damage)
    @hp -= damage
  end

  def kill!
    GlobalGameState::ACTORS.delete(GlobalGameState::ACTORS.key(self))
  end

  def decide_move
    player = GlobalGameState::PLAYER
    if is_near? player
      actor_path = TCOD::Path.by_map(tcod_map, diagonalCost=0.0)
      actor_path.compute(@pos_x, @pos_y, player.pos_x, player.pos_y)
      px, py = actor_path.walk
      if px == false
        return :rest
      end
  
      dx, dy = px - @pos_x, py - @pos_y
      dir = delta_to_dir(dx, dy)
    else
      dir = free_moves.sample
    end
    dir
  end

  def move(dir)
    return false unless can_move? dir
    return true if dir == :rest

    dy = dx = 0

    dy += 1 if dir == :south
    dy -= 1 if dir == :north
    dx -= 1 if dir == :west
    dx += 1 if dir == :east
  
    other_actor = Actor.actor_at_position(@pos_y + dy, @pos_x + dx)
    if other_actor
      if hostile_towards? other_actor
        proc_attack other_actor
        # attack takes place, but position doesn't change
        return true
      else
        # FIXME make actors more intelligent
        msg_log "DEBUG: #{@name} can't move w/o killing a friendly; forcing rest"
        return false
      end
    else
      @pos_x += dx; @pos_y += dy
    end
  
    tcod_map.compute_fov(@pos_x, @pos_y, @sight_range, true, TCOD::FOV_DIAMOND)
    true
  end

  def within_line_of_sight?(col_ind, row_ind)
    tcod_map.in_fov?(col_ind, row_ind)
  end
  
  def self.actor_at_position(row, col)
    GlobalGameState::ACTORS.values.each do |actor|
      return actor if actor.pos_x == col && actor.pos_y == row
    end
    return nil
  end

  private

  def free_moves
    [:north, :south, :west, :east].select { |dir| can_move? dir }
  end

  def is_near?(other_actor, distance=8)
    distance_to(other_actor.pos_x, other_actor.pos_y) < distance
  end

  def distance_to(col, row)
    dx = @pos_x - col
    dy = @pos_y - row
    dx.abs + dy.abs
  end

  def hostile_towards?(other_actor)
    @allegiance != other_actor.allegiance
  end

  def can_move?(dir)
    dx, dy = dir_to_delta(dir)
    @dungeon_level.walkable?(@pos_x + dx, @pos_y + dy)
  end

  def dir_to_delta(dir)
    return [ 0, 1] if dir == :south
    return [ 0,-1] if dir == :north
    return [-1, 0] if dir == :west
    return [ 1, 0] if dir == :east
    return [ 0, 0]
  end

  def proc_attack(victim)
    # TODO expand to victims, plural
    # `self` is the assailant
    victim.hurt 1
    if victim.player? && victim.alive?
      msg_log "Ouch! HP remaining: #{victim.hp}"
    end
    if not victim.alive?
      msg_log "#{@name} killed #{victim.name}"
      victim.kill!
      if victim.player?
        msg_log "The Dashing Hero has died. Score: 0"
        exit_game
      end
    end
  end

  def make_tcod_map_from_dungeon_level
    dlevel = @dungeon_level.cells
    tmap = TCOD::Map.new(dlevel.first.count, dlevel.count)
    dlevel.each_with_index do |level_row, row_ind|
      level_row.each_with_index do |cell, col_ind|
        tmap.set_properties(col_ind, row_ind, @dungeon_level.transparent?(col_ind, row_ind),
                                              @dungeon_level.walkable?(col_ind, row_ind))
      end
    end
    tmap
  end

  def delta_to_dir(dx, dy)
    return :north if dy < 0
    return :south if dy > 0
    return :west if dx < 0
    return :east if dx > 0
    return :rest
  end
end

