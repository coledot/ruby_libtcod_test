require 'libtcod'

class Drawing
  LIMIT_FPS = 20
  SCREEN_ROWS = 24
  SCREEN_COLS = 60

  SCREEN_MSG_LOG_OFFSET_ROWS = 18 # FIXME dependent on MSG_LOG_ROWS

  DEFAULT_SCREEN_FORE_COLOR = TCOD::Color::LIGHTEST_GREY
  DEFAULT_SCREEN_BACK_COLOR = TCOD::Color::BLACK

  def initialize(map_rows, map_cols)
    @map_rows, @map_cols = map_rows, map_cols
    TCOD.console_set_custom_font('dejavu16x16_gs_tc.png',
                                 TCOD::FONT_TYPE_GREYSCALE | TCOD::FONT_LAYOUT_TCOD, 0, 0)
    TCOD.console_init_root(SCREEN_COLS, SCREEN_ROWS, 'tcod test', false, TCOD::RENDERER_SDL)
    TCOD.sys_set_fps(LIMIT_FPS)

    # offset of map within screen
    @screen_map_offset_rows = 1 #(SCREEN_ROWS - @map_rows) / 2
    @screen_map_offset_cols = 1 #(SCREEN_COLS - @map_cols) / 2
  end

  def draw_shit
    draw_background
    draw_map
    draw_actors
    draw_log
 
    TCOD.console_flush()
  end

  private

  def draw_background
    TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
    TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
    (0...SCREEN_ROWS).each do |screen_row|
      (0...SCREEN_COLS).each do |screen_col|
        TCOD.console_put_char(nil, screen_col, screen_row, ' '.ord, TCOD::BKGND_SET)
      end
    end
  end

  def draw_map
    GlobalGameState::DUNGEON_LEVEL.cells.each_with_index do |level_row, row_ind|
      level_row.each_with_index do |cell, col_ind|
        # TODO map_location_to_screen_location(...)
        draw_char_to_location(cell, {x: col_ind+@screen_map_offset_cols,
                                     y: row_ind+@screen_map_offset_rows})
      end
    end
  end

  def draw_actors
    GlobalGameState::ACTORS.values.each do |actor|
      TCOD.console_set_default_foreground(nil, actor.fore_color)
      TCOD.console_set_default_background(nil, actor.back_color)
      # TODO map_location_to_screen_location(...)
      draw_char_to_location(actor.sigil, {x: actor.pos_x+@screen_map_offset_cols,
                                          y: actor.pos_y+@screen_map_offset_rows})
      TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)

      TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
    end
  end

  def draw_log
    GlobalGameState::MSG_LOG.last(MSG_LOG_ROWS).each_with_index do |msg, i|
      TCOD.console_print(nil, TCOD::LEFT, SCREEN_MSG_LOG_OFFSET_ROWS+i, msg)
    end
  end

  def draw_char_to_location(char, location)
    TCOD.console_put_char(nil, location[:x], location[:y], char.ord, TCOD::BKGND_SET)
  end
end

