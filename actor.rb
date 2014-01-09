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
      dir = coords_to_dir(dx, dy)
    else
      dir = free_moves.sample
    end
    dir
  end

  def move(dir)
    return false unless can_move? dir
  
    if dir == :left
      new_pos = { x: @pos_x - 1, y: @pos_y }
    elsif dir == :right
      new_pos = { x: @pos_x + 1, y: @pos_y }
    elsif dir == :up
      new_pos = { x: @pos_x, y: @pos_y - 1 }
    elsif dir == :down
      new_pos = { x: @pos_x, y: @pos_y + 1 }
    elsif dir == :rest
      # resting always succeeds
      return true
    end
  
    other_actor = Actor.actor_at_location(new_pos)
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
      @pos_x, @pos_y = new_pos[:x], new_pos[:y]
    end
  
    tcod_map.compute_fov(@pos_x, @pos_y, @sight_range, true, TCOD::FOV_BASIC)
    true
  end

  def within_line_of_sight?(col_ind, row_ind)
    tcod_map.in_fov?(col_ind, row_ind)
  end
  
  def self.actor_at_location(location)
    GlobalGameState::ACTORS.values.each do |actor|
      actor_location = { x: actor.pos_x, y: actor.pos_y }
      return actor if actor_location == location
    end
    return nil
  end

  private

  def free_moves
    [:up, :down, :left, :right].select { |dir| can_move? dir }
  end

  def where_am_i
    @dungeon_level.cells
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
    level = where_am_i

    if dir == :left
      @pos_x > 0 && level[@pos_y][@pos_x-1] == '.'
    elsif dir == :right
      @pos_x < MAP_COLS - 1 && level[@pos_y][@pos_x+1] == '.'
    elsif dir == :up
      @pos_y > 0 && level[@pos_y-1][@pos_x] == '.'
    elsif dir == :down
      @pos_y < MAP_ROWS - 1 && level[@pos_y+1][@pos_x] == '.'
    elsif dir == :rest
      true
    end
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
    dlevel = where_am_i
    tmap = TCOD::Map.new(dlevel.first.count, dlevel.count)
    dlevel.each_with_index do |level_row, row_ind|
      level_row.each_with_index do |cell, col_ind|
        tmap.set_properties(col_ind, row_ind, @dungeon_level.transparent?(col_ind, row_ind),
                                              @dungeon_level.walkable?(col_ind, row_ind))
      end
    end
    tmap
  end

  def coords_to_dir(dx, dy)
    if dx < 0 && dy == 0
      :left
    elsif dx > 0 && dy == 0
      :right
    elsif dx == 0 && dy < 0
      :up
    elsif dx == 0 && dy > 0
      :down
    end
  end
end

