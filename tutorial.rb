require 'libtcod'

# TODO log on all deaths
LIMIT_FPS = 20
MAP_ROWS = 16
MAP_COLS = 32

SCREEN_ROWS = 48
SCREEN_COLS = 80

# offset of map within screen
#SCREEN_MAP_OFFSET_ROWS=1
#SCREEN_MAP_OFFSET_COLS=1
SCREEN_MAP_OFFSET_ROWS = (SCREEN_ROWS - MAP_ROWS) / 2
SCREEN_MAP_OFFSET_COLS = (SCREEN_COLS - MAP_COLS) / 2

ACTORS_MAX = 20

DEFAULT_SCREEN_FORE_COLOR = TCOD::Color::LIGHTEST_GREY
DEFAULT_SCREEN_BACK_COLOR = TCOD::Color::BLACK

def handle_keys
  player_moved = false
  key = TCOD.console_wait_for_keypress(true)

  if key.vk == TCOD::KEY_ESCAPE
    # FIXME lol
    return true, player_moved #exit game
  end

  player = $actors[:player]
  #movement keys
  if key.pressed
    if key.c == 'k'
      player_moved = move(player, :up)
    elsif key.c == 'j'
      player_moved = move(player, :down)
    elsif key.c == 'h'
      player_moved = move(player, :left)
    elsif key.c == 'l'
      player_moved = move(player, :right)
    elsif key.c == '.'
      #puts "DEBUG: player is resting"
      player_moved = move(player, :rest)
      # FIXME lol
      return false, true
    else
      #puts "DEBUG: unknown command: #{key.c}"
      # FIXME lol
      return false, false
    end
    #puts "DEBUG: after move; player pos is (#{player[:x]}, #{player[:y]})"

    unless player_moved
      #puts "DEBUG: player did not make a valid move this turn"
    end
  end
  # FIXME lol
  return false, player_moved
end

$prng = Random.new

def init_map
  mapp = []
  MAP_ROWS.times do |row|
    new_row = []
    MAP_COLS.times do |col|
      if $prng.rand > 0.8
        new_row.push "#"
      else
        new_row.push "."
      end
    end
    mapp.push new_row
  end
  mapp
end

def init_actors
  # start w/ just the player
  $actors = {
    player: {
      sigil: '@',
      fore_color: TCOD::Color::WHITE,
      back_color: TCOD::Color::DARKER_GREY,
      x: $prng.rand(MAP_COLS),
      y: $prng.rand(MAP_ROWS),
      hp: 3,
      name: "The Dashing Hero",
      allegiance: :player,
      player: true
    }
  }
  # now add baddies
  (ACTORS_MAX-1).times do |n|
    bsym = :"baddie_#{n}"
    $actors[bsym] = {
      sigil: 'e',
      fore_color: TCOD::Color::LIGHT_SEPIA,
      back_color: TCOD::Color::BLACK,
      x: $prng.rand(MAP_COLS),
      y: $prng.rand(MAP_ROWS),
      hp: 1,
      allegiance: :baddies,
      name: "Generic Bad Guy ##{n}"
    }
  end
  $actors
end

def can_move?(actor, dir)
  #puts "DEBUG: actor #{actor[:name]} dir #{dir}"
  if dir == :left
    actor[:x] > 0 && $dungeon_level[actor[:y]][actor[:x]-1] == '.'
  elsif dir == :right
    actor[:x] < MAP_COLS - 1 && $dungeon_level[actor[:y]][actor[:x]+1] == '.'
  elsif dir == :up
    actor[:y] > 0 && $dungeon_level[actor[:y]-1][actor[:x]] == '.'
  elsif dir == :down
    actor[:y] < MAP_ROWS - 1 && $dungeon_level[actor[:y]+1][actor[:x]] == '.'
  elsif dir == :rest
    true
  end
end

def actor_at_location(location)
  $actors.values.each do |actor|
    actor_location = { x: actor[:x], y: actor[:y] }
    return actor if actor_location == location
  end
  return nil
end

def near(actor, other_actor, distance=8)
  dx = actor[:x] - other_actor[:x]
  dy = actor[:y] - other_actor[:y]
  #puts "DEBUG: distance from #{actor[:name]} to #{other_actor[:name]}: #{(dx + dy).abs}"
  (dx + dy).abs < distance
end

def dir_to(actor, other_actor)
  dx = actor[:x] - other_actor[:x]
  dy = actor[:y] - other_actor[:y]
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

def transparent?(cell)
  cell != '#'
end

def walkable?(cell)
  cell == '.'
end

def make_tcod_map_from_dungeon_level(dungeon_level)
  #tcod_map = TCOD.map_new(dungeon_level.first.count, dungeon_level.count)
  tcod_map = TCOD::Map.new(dungeon_level.first.count, dungeon_level.count)
  dungeon_level.each_with_index do |level_row, row_ind|
    level_row.each_with_index do |cell, col_ind|
      tcod_map.set_properties(col_ind, row_ind, transparent?(cell), walkable?(cell))
    end
  end
  tcod_map
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

def decide_move(actor)
  player = $actors[:player]
  if near(actor,player)
    actor_map = make_tcod_map_from_dungeon_level $dungeon_level
    actor_path = TCOD::Path.by_map(actor_map, diagonalCost=0.0)
    actor_path.compute(actor[:x], actor[:y], player[:x], player[:y])
    px, py = actor_path.walk
    #puts "DEBUG: walk returned px: #{px} py: #{py}"
    if px == false
      #puts "DEBUG: #{actor[:name]} nowhere to move; resting"
      return :rest
    end

    dx, dy = px - actor[:x], py - actor[:y]
    #puts "DEBUG: dx: #{dx} dy: #{dy}"
    dir = coords_to_dir(dx, dy)
  else
    #puts "DEBUG: #{actor[:name]} is wandering"
    dir = [:up, :down, :left, :right].sample
  end
  dir
end

def player?(actor)
  actor[:player] == true
end

def alive?(actor)
  actor[:hp] > 0
end

def proc_attack(assailant, victim)
  victim[:hp] -= 1
  #puts "DEBUG: #{other_actor[:name]}: ouch! #{other_actor[:hp]} hp remain"
  if player?(victim) && alive?(victim)
    puts "Ouch! HP remaining: #{victim[:hp]}"
  end
  if not alive?(victim)
    #puts "DEBUG: deleting victim #{victim} cause it's dead"
    puts "#{assailant[:name]} killed #{victim[:name]}"
    $actors.delete($actors.key(victim))
    if player?(victim)
      puts "The Dashing Hero has died. Score: 0"
      exit 0
    end
  end
end

def hostile_towards?(actor, other_actor)
  actor[:allegiance] != other_actor[:allegiance]
end

def move(actor, dir)
  return false unless can_move? actor, dir

  if dir == :left
    new_pos = { x: actor[:x] - 1, y: actor[:y] }
  elsif dir == :right
    new_pos = { x: actor[:x] + 1, y: actor[:y] }
  elsif dir == :up
    new_pos = { x: actor[:x], y: actor[:y] - 1 }
  elsif dir == :down
    new_pos = { x: actor[:x], y: actor[:y] + 1 }
  elsif dir == :rest
    return true
  end

  other_actor = actor_at_location(new_pos)
  if other_actor
    if hostile_towards?(actor, other_actor)
      proc_attack(actor, other_actor)
      # attack takes place, but position doesn't change
      return true
    else
      # FIXME make actors more intelligent
      puts "DEBUG: #{actor[:name]} can't move w/o killing a friendly; forcing rest"
      return false
    end
  else
    actor[:x], actor[:y] = new_pos[:x], new_pos[:y]
  end

  return true
end

def initialize_game
  TCOD.console_set_custom_font('dejavu16x16_gs_tc.png',
                               TCOD::FONT_TYPE_GREYSCALE | TCOD::FONT_LAYOUT_TCOD, 0, 0)
  TCOD.console_init_root(SCREEN_COLS, SCREEN_ROWS, 'tcod test', false, TCOD::RENDERER_SDL)
  TCOD.sys_set_fps(LIMIT_FPS)
  
  $dungeon_level = init_map
  $actors = init_actors
end

def draw_shit
  # draw background
  TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
  TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
  (0...SCREEN_ROWS).each do |screen_row|
    (0...SCREEN_COLS).each do |screen_col|
      TCOD.console_put_char(nil, screen_col, screen_row, ' '.ord, TCOD::BKGND_SET)
    end
  end

  # draw map
  $dungeon_level.each_with_index do |level_row, row_ind|
    level_row.each_with_index do |cell, col_ind|
      TCOD.console_put_char(nil, col_ind+SCREEN_MAP_OFFSET_COLS, row_ind+SCREEN_MAP_OFFSET_ROWS,
                            cell.ord, TCOD::BKGND_SET)
    end
  end

  # draw actors
  $actors.values.each do |actor|
    # FIXME is the fore/background swap really necessary? (probably, yes)
    TCOD.console_set_default_foreground(nil, actor[:fore_color])
    TCOD.console_set_default_background(nil, actor[:back_color])
    TCOD.console_put_char(nil, actor[:x]+SCREEN_MAP_OFFSET_COLS, actor[:y]+SCREEN_MAP_OFFSET_ROWS,
                          actor[:sigil].ord, TCOD::BKGND_SET)
    # FIXME is the fore/background swap really necessary?
    TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
    TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
  end
  TCOD.console_flush()
end

def player_is_alone?
  $actors.values.count == 1 && (not $actors[:player].nil?)
end

###

initialize_game

until TCOD.console_is_window_closed
  draw_shit

  # handle keys and exit game if needed
  # process player input (done in handle_keys)
  # FIXME clumsily handled return values
  will_exit, player_acted = handle_keys
  break if will_exit
  
  if player_acted
    # allow other actors to, well, act
    $actors.values.select{ |a| not a[:player] }.each do |actor|
      move_dir = decide_move(actor)
      #puts "DEBUG: #{actor[:name]} decides to move #{move_dir}"
      move(actor, move_dir)
    end
  end

  if player_is_alone?
    puts "You win!!! Score is 100."
    exit 0
  end
end

