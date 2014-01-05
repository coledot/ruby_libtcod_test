require 'libtcod'

module Drawing
  def self.draw_shit
    draw_background
    draw_map
    draw_actors
    draw_log
 
    TCOD.console_flush()
  end

  def self.draw_background
    TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
    TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
    (0...SCREEN_ROWS).each do |screen_row|
      (0...SCREEN_COLS).each do |screen_col|
        TCOD.console_put_char(nil, screen_col, screen_row, ' '.ord, TCOD::BKGND_SET)
      end
    end
  end

  def self.draw_map
    $dungeon_level.each_with_index do |level_row, row_ind|
      level_row.each_with_index do |cell, col_ind|
        TCOD.console_put_char(nil, col_ind+SCREEN_MAP_OFFSET_COLS, row_ind+SCREEN_MAP_OFFSET_ROWS,
                              cell.ord, TCOD::BKGND_SET)
      end
    end
  end

  def self.draw_actors
    $actors.values.each do |actor|
      TCOD.console_set_default_foreground(nil, actor.fore_color)
      TCOD.console_set_default_background(nil, actor.back_color)
      TCOD.console_put_char(nil, actor.pos_x+SCREEN_MAP_OFFSET_COLS, actor.pos_y+SCREEN_MAP_OFFSET_ROWS,
                            actor.sigil.ord, TCOD::BKGND_SET)
      TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
      TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
    end
  end

  def self.draw_log
    $msg_log.last(MSG_LOG_ROWS).each_with_index do |msg, i|
      TCOD.console_print(nil, TCOD::LEFT, SCREEN_MSG_LOG_OFFSET_ROWS+i, msg)
    end
  end
end

