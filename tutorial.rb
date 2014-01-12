require 'libtcod'

require './actor'
require './drawing'
require './dungeon_level'

MAP_ROWS = 32
MAP_COLS = 48

MSG_LOG_ROWS = 6
MSG_LOG_COLS = 80
MAX_MSG_LEN = MSG_LOG_COLS - 2

ACTORS_MAX = 40

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
  return false if input_key == "\x00"

  player = GlobalGameState::PLAYER

  # TODO implement running
  # movement keys
  player_moved = if input_key == 'k'
    player.move :north
  elsif input_key == 'j'
    player.move :south
  elsif input_key == 'h'
    player.move :west
  elsif input_key == 'l'
    player.move :east
  elsif input_key == '.'
    player.move :rest
  else
    msg_log "DEBUG: unknown command: #{input_key}"
    false
  end

  return player_moved
end

# TODO refactor all world data into a single global, for easy save/export
# TODO create actors w/o a position; place them later
def init_actors(dungeon_level)
  # start w/ just the player
  player = Actor.new(dungeon_level, {
      sigil: '@',
      fore_color: TCOD::Color::WHITE,
      back_color: TCOD::Color::DARKER_GREY,
      #x: GlobalGameState::PRNG.rand(MAP_COLS),
      #y: GlobalGameState::PRNG.rand(MAP_ROWS),
      hp: 3,
      name: "The Dashing Hero",
      allegiance: :player,
      player: true
    })
  actors = {
    player: player
  }
  # now add baddies
  (ACTORS_MAX-1).times do |n|
    badguy = Actor.new(dungeon_level, {
      sigil: 'e',
      fore_color: TCOD::Color::SEPIA,
      back_color: TCOD::Color::BLACK,
      #x: GlobalGameState::PRNG.rand(MAP_COLS),
      #y: GlobalGameState::PRNG.rand(MAP_ROWS),
      hp: 1,
      allegiance: :baddies,
      name: "Generic Bad Guy ##{n}"
    })
    bsym = :"baddie_#{n}"
    actors[bsym] = badguy
  end
  $dungeon_level.apply_template!
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
$drawer = Drawing.new MSG_LOG_ROWS
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

  # NOTE keep in mind, a proper time system will likely need to be implemented at some point,
  #      so things will get more complicated than "player goes, monsters go, repeat until end"
  if player_acted
    process_nonplayer_actors

    if player_is_alone?
      msg_log "You win!!! Score is 100."
      exit_game
    end
  end
end

