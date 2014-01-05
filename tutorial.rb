require 'libtcod'

LIMIT_FPS = 20
MAP_ROWS = 16
MAP_COLS = 32

SCREEN_ROWS = 48
SCREEN_COLS = 80

# offset of map within screen
SCREEN_MAP_OFFSET_ROWS = (SCREEN_ROWS - MAP_ROWS) / 2
SCREEN_MAP_OFFSET_COLS = (SCREEN_COLS - MAP_COLS) / 2

MSG_LOG_ROWS = 4
MSG_LOG_COLS = 40
MAX_MSG_LEN = MSG_LOG_COLS - 2
SCREEN_MSG_LOG_OFFSET_ROWS = 44
SCREEN_MSG_LOG_OFFSET_COLS = 0

ACTORS_MAX = 20

DEFAULT_SCREEN_FORE_COLOR = TCOD::Color::LIGHTEST_GREY
DEFAULT_SCREEN_BACK_COLOR = TCOD::Color::BLACK

def get_input
  key = TCOD.console_wait_for_keypress(true)

  if key.vk == TCOD::KEY_ESCAPE
    return TCOD::KEY_ESCAPE
  end

  if key.pressed
    return key.c
  end

  return nil
end

def process_player_input input_key
  player = $actors[:player]

  # movement keys
  player_moved = if input_key == 'k'
    move(player, :up)
  elsif input_key == 'j'
    move(player, :down)
  elsif input_key == 'h'
    move(player, :left)
  elsif input_key == 'l'
    move(player, :right)
  elsif input_key == '.'
    #puts "DEBUG: player is resting"
    move(player, :rest)
  else
    #puts "DEBUG: unknown command: #{key.c}"
    false
  end

  return player_moved
end

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

#class Actor
#  def initialize
#
#  end
#end

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

def is_near?(actor, other_actor, distance=8)
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

def allies_of(actor)
  $actors.values.select{|a| a[:allegiance] == actor[:allegiance]}
end

def hostile_towards?(actor, other_actor)
  actor[:allegiance] != other_actor[:allegiance]
end

def ally_at?(actor, col, row)
  other_actor = actor_at_location({x: col, y: row})
  return false unless other_actor

  allies = allies_of actor
  allies.include? other_actor
end

def walkable?(actor, col, row, cell)
  cell == '.' && (not ally_at?(actor, col, row))
end

def make_tcod_map_from_dungeon_level(actor, dungeon_level)
  tcod_map = TCOD::Map.new(dungeon_level.first.count, dungeon_level.count)
  dungeon_level.each_with_index do |level_row, row_ind|
    level_row.each_with_index do |cell, col_ind|
      tcod_map.set_properties(col_ind, row_ind, transparent?(cell),
                              walkable?(actor, col_ind, row_ind, cell))
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

def free_moves(actor)
  [:up, :down, :left, :right].select { |dir| can_move? actor, dir }
end

def decide_move(actor)
  player = $actors[:player]
  if is_near?(actor,player)
    actor_map = make_tcod_map_from_dungeon_level(actor, $dungeon_level)
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
    #dir = [:up, :down, :left, :right].sample
    #puts "DEBUG: free_moves(#{actor[:name]}) is #{free_moves(actor)}"
    dir = free_moves(actor).sample
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
    msg_log "Ouch! HP remaining: #{victim[:hp]}"
  end
  if not alive?(victim)
    #puts "DEBUG: deleting victim #{victim} cause it's dead"
    msg_log"#{assailant[:name]} killed #{victim[:name]}"
    $actors.delete($actors.key(victim))
    if player?(victim)
      msg_log "The Dashing Hero has died. Score: 0"
      exit 0
    end
  end
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
    # resting always succeeds
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
      msg_log "DEBUG: #{actor[:name]} can't move w/o killing a friendly; forcing rest"
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

  msg_log "The Dashing Hero finds him/herself in a sticky situation."
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
    TCOD.console_set_default_foreground(nil, actor[:fore_color])
    TCOD.console_set_default_background(nil, actor[:back_color])
    TCOD.console_put_char(nil, actor[:x]+SCREEN_MAP_OFFSET_COLS, actor[:y]+SCREEN_MAP_OFFSET_ROWS,
                          actor[:sigil].ord, TCOD::BKGND_SET)
    TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
    TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
  end

  # draw log
  $msg_log.last(4).each_with_index do |msg, i|
    msg.chars.each_with_index do |c, j|
      TCOD.console_put_char(nil, j, SCREEN_MSG_LOG_OFFSET_ROWS+i, c.ord, TCOD::BKGND_SET)
    end
  end

  TCOD.console_flush()
end

def player_is_alone?
  $actors.values.count == 1 && (not $actors[:player].nil?)
end

def process_actors
  $actors.values.select{ |a| not a[:player] }.each do |actor|
    move_dir = decide_move(actor)
    #puts "DEBUG: #{actor[:name]} decides to move #{move_dir}"
    move(actor, move_dir)
  end
end

def msg_log(msg)
  while msg.length > MAX_MSG_LEN
    shorter_msg = msg[0...MAX_MSG_LEN]
    $msg_log.push shorter_msg + " _"
    msg = msg[MAX_MSG_LEN..-1]
  end
  $msg_log.push msg if msg.length > 0
end

###

$msg_log = []
$prng = Random.new

initialize_game

until TCOD.console_is_window_closed
  draw_shit

  entered_key = get_input
  break if entered_key == TCOD::KEY_ESCAPE
  player_acted = process_player_input entered_key

  if player_acted
    process_actors

    if player_is_alone?
      msg_log "You win!!! Score is 100. Press [ESC] to exit."
    end
  end
end

