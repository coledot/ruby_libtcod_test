require 'libtcod'

require './actor'

LIMIT_FPS = 20
MAP_ROWS = 16
MAP_COLS = 32

SCREEN_ROWS = 48
SCREEN_COLS = 80

# offset of map within screen
SCREEN_MAP_OFFSET_ROWS = (SCREEN_ROWS - MAP_ROWS) / 2
SCREEN_MAP_OFFSET_COLS = (SCREEN_COLS - MAP_COLS) / 2

MSG_LOG_ROWS = 4
MSG_LOG_COLS = 60
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
    player.move :up
  elsif input_key == 'j'
    player.move :down
  elsif input_key == 'h'
    player.move :left
  elsif input_key == 'l'
    player.move :right
  elsif input_key == '.'
    player.move :rest
  else
    msg_log "DEBUG: unknown command: #{input_key}"
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

# TODO refactor all world data into a single global, for easy save/export
def init_actors
  # start w/ just the player
  $actors = {
    player: Actor.new($dungeon_level, {
      sigil: '@',
      fore_color: TCOD::Color::WHITE,
      back_color: TCOD::Color::DARKER_GREY,
      x: $prng.rand(MAP_COLS),
      y: $prng.rand(MAP_ROWS),
      hp: 3,
      name: "The Dashing Hero",
      allegiance: :player,
      player: true
    })
  }
  # now add baddies
  (ACTORS_MAX-1).times do |n|
    bsym = :"baddie_#{n}"
    $actors[bsym] = Actor.new($dungeon_level, {
      sigil: 'e',
      fore_color: TCOD::Color::LIGHT_SEPIA,
      back_color: TCOD::Color::BLACK,
      x: $prng.rand(MAP_COLS),
      y: $prng.rand(MAP_ROWS),
      hp: 1,
      allegiance: :baddies,
      name: "Generic Bad Guy ##{n}"
    })
  end
  $actors
end

def actor_at_location(location)
  $actors.values.each do |actor|
    actor_location = { x: actor.pos_x, y: actor.pos_y }
    return actor if actor_location == location
  end
  return nil
end

def transparent?(cell)
  cell != '#'
end

def allies_of(actor)
  $actors.values.select{|a| a.allegiance == actor.allegiance}
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
    TCOD.console_set_default_foreground(nil, actor.fore_color)
    TCOD.console_set_default_background(nil, actor.back_color)
    TCOD.console_put_char(nil, actor.pos_x+SCREEN_MAP_OFFSET_COLS, actor.pos_y+SCREEN_MAP_OFFSET_ROWS,
                          actor.sigil.ord, TCOD::BKGND_SET)
    TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
    TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
  end

  # draw log
  # FIXME derp, libtcod has better primitives for writing strings to the screen
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

def process_nonplayer_actors
  $actors.values.select{ |a| not a.player? }.each do |actor|
    move_dir = actor.decide_move
    actor.move move_dir
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
    process_nonplayer_actors

    if player_is_alone?
      msg_log "You win!!! Score is 100. Press [ESC] to exit."
    end
  end
end

