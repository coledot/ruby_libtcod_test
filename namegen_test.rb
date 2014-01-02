require 'libtcod'

TCOD.namegen_parse("./custom_namegen.cfg", nil)
10.times { puts TCOD.namegen_generate "neutral", false }

