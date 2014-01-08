require 'libtcod'

require './actor'
require './drawing'
require './dungeon_level'

MAP_ROWS = 16
MAP_COLS = 32

MSG_LOG_ROWS = 6
MSG_LOG_COLS = 60
MAX_MSG_LEN = MSG_LOG_COLS - 2

ACTORS_MAX = 20

def process_input
  entered_key = get_input
  exit_game if entered_key == TCOD::KEY_ESCAPE
  process_player_input entered_key
end

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
  return false unless input_key

  player = GlobalGameState::PLAYER

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

# TODO refactor all world data into a single global, for easy save/export
def init_actors(dungeon_level)
  # start w/ just the player
  actors = {
    player: Actor.new(dungeon_level, {
      sigil: '@',
      fore_color: TCOD::Color::WHITE,
      back_color: TCOD::Color::DARKER_GREY,
      x: GlobalGameState::PRNG.rand(MAP_COLS),
      y: GlobalGameState::PRNG.rand(MAP_ROWS),
      hp: 3,
      name: "The Dashing Hero",
      allegiance: :player,
      player: true
    })
  }
  # now add baddies
  (ACTORS_MAX-1).times do |n|
    bsym = :"baddie_#{n}"
    actors[bsym] = Actor.new(dungeon_level, {
      sigil: 'e',
      fore_color: TCOD::Color::LIGHT_SEPIA,
      back_color: TCOD::Color::BLACK,
      x: GlobalGameState::PRNG.rand(MAP_COLS),
      y: GlobalGameState::PRNG.rand(MAP_ROWS),
      hp: 1,
      allegiance: :baddies,
      name: "Generic Bad Guy ##{n}"
    })
  end
  actors
end

def player_is_alone?
  GlobalGameState::ACTORS.values.count == 1 && (not GlobalGameState::PLAYER.nil?)
end

def process_nonplayer_actors
  GlobalGameState::ACTORS.values.select{ |a| not a.player? }.each do |actor|
    move_dir = actor.decide_move
    actor.move move_dir
  end
end

def msg_log(msg)
  while msg.length > MAX_MSG_LEN
    shorter_msg = msg[0...MAX_MSG_LEN]
    GlobalGameState::MSG_LOG.push shorter_msg + " _"
    msg = msg[MAX_MSG_LEN..-1]
  end
  GlobalGameState::MSG_LOG.push msg if msg.length > 0
end

def exit_game
  msg_log "Press any key to exit."
  GlobalUtilityState::DRAWER.draw_shit
  k = get_input
  while k == nil do
    k = get_input
  end
  exit 0
end

###

$msg_log = []
$prng = Random.new
$drawer = Drawing.new
module GlobalGameState
  PRNG = $prng
end
$dungeon_level = DungeonLevel.new MAP_ROWS, MAP_COLS
$actors = init_actors $dungeon_level

module GlobalGameState
  # to be eventually replaced with DUNGEON, then WORLD, etc.
  DUNGEON_LEVEL = $dungeon_level
  ACTORS = $actors
  PLAYER = $actors[:player]
  MSG_LOG = $msg_log
end

module GlobalUtilityState
  DRAWER = $drawer
end

msg_log "The Dashing Hero finds him/herself in a sticky situation."

until TCOD.console_is_window_closed
  $drawer.draw_shit

  player_acted = process_input

  if player_acted
    process_nonplayer_actors

    if player_is_alone?
      msg_log "You win!!! Score is 100."
      exit_game
    end
  end
end

