require 'libtcod'

class Actor
  GENERIC_ACTOR_OPTIONS = {
    sigil: '*',
    fore_color: TCOD::Color::WHITE,
    back_color: TCOD::Color::BLACK,
    x: 0,
    y: 0,
    hp: 1,
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
    @current_dlevel = current_dlevel
  end
  attr_accessor :sigil, :fore_color, :back_color, :pos_x, :pos_y, :hp, :name, :allegiance

  def player?
    @player
  end

  def hurt!(damage)
    @hp -= damage
  end

  # XXX nevermind the philosophical dillemmas, "should a zombie ever return true for .alive()?" etc.
  def alive?
    @hp > 0
  end

  def free_moves
    [:up, :down, :left, :right].select { |dir| can_move? dir }
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

  def where_am_i
    @current_dlevel
  end

  def is_near?(other_actor, distance=8)
    dx = @pos_x - other_actor.pos_x
    dy = @pos_y - other_actor.pos_y
    (dx + dy).abs < distance
  end

  def hostile_towards?(other_actor)
    @allegiance != other_actor.allegiance
  end

  def decide_move
    # FIXME remove dependence on globals
    player = $actors[:player]
    if is_near? player
      actor_map = make_tcod_map_from_dungeon_level(self, where_am_i)
      actor_path = TCOD::Path.by_map(actor_map, diagonalCost=0.0)
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
  
    other_actor = actor_at_location(new_pos)
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
  
    true
  end

  def proc_attack(victim)
    # TODO expand to victims, plural
    # `self` is the assailant
    victim.hurt! 1
    if victim.player? && victim.alive?
      msg_log "Ouch! HP remaining: #{victim.hp}"
    end
    if not victim.alive?
      msg_log"#{@name} killed #{victim.name}"
      # FIXME remove dependence on globals
      $actors.delete($actors.key(victim))
      if victim.player?
        msg_log "The Dashing Hero has died. Score: 0"
        exit 0
      end
    end
  end

  def dir_to(other_actor)
    dx = @pos_x - other_actor.pos_x
    dy = @pos_y - other_actor.pos_y
    if dx.abs > dy.abs
      if dx > 0
        :left
      else
        :right
      end
    else
      if dy > 0
        :up
      else
        :down
      end
    end
  end
end

