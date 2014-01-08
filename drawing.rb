require 'libtcod'

class Drawing
  LIMIT_FPS = 20
  SCREEN_ROWS = 24
  SCREEN_COLS = 60

  SCREEN_MSG_LOG_OFFSET_ROWS = 18 # FIXME dependent on MSG_LOG_ROWS

  DEFAULT_SCREEN_FORE_COLOR = TCOD::Color::LIGHTEST_GREY
  DEFAULT_SCREEN_BACK_COLOR = TCOD::Color::BLACK

  def initialize()
    TCOD.console_set_custom_font('dejavu16x16_gs_tc.png',
                                 TCOD::FONT_TYPE_GREYSCALE | TCOD::FONT_LAYOUT_TCOD, 0, 0)
    TCOD.console_init_root(SCREEN_COLS, SCREEN_ROWS, 'tcod test', false, TCOD::RENDERER_SDL)
    TCOD.sys_set_fps(LIMIT_FPS)

    # offset of map within screen
    @screen_map_offset_rows = 1
    @screen_map_offset_cols = 1
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
    player = GlobalGameState::PLAYER
    GlobalGameState::DUNGEON_LEVEL.cells.each_with_index do |level_row, row_ind|
      level_row.each_with_index do |cell, col_ind|
        screen_location = map_location_to_screen_location(col_ind, row_ind)
        if player.within_line_of_sight?(col_ind, row_ind)
          back_color = TCOD::Color::DARKER_GREY
        else
          back_color = TCOD::Color::BLACK
        end
        draw_char_to_location(cell, screen_location, back_color: back_color)
      end
    end
  end

  def draw_actors
    player = GlobalGameState::PLAYER
    GlobalGameState::ACTORS.values.each do |actor|
      screen_location = map_location_to_screen_location(actor.pos_x, actor.pos_y)
      back_color = if actor.player? || player.within_line_of_sight?(actor.pos_x, actor.pos_y)
        TCOD::Color::DARKER_GREY
      else
        TCOD::Color::BLACK
      end
      draw_char_to_location(actor.sigil, screen_location, fore_color: actor.fore_color,
                                                          back_color: back_color)
    end
  end

  def draw_log
    GlobalGameState::MSG_LOG.last(MSG_LOG_ROWS).each_with_index do |msg, i|
      TCOD.console_print(nil, TCOD::LEFT, SCREEN_MSG_LOG_OFFSET_ROWS+i, msg)
    end
  end

  def draw_char_to_location(char, location, options={})
    default_options = {
      fore_color: DEFAULT_SCREEN_FORE_COLOR,
      back_color: DEFAULT_SCREEN_BACK_COLOR
    }
    options = default_options.merge(options)
    TCOD.console_set_default_foreground(nil, options[:fore_color])
    TCOD.console_set_default_background(nil, options[:back_color])
    TCOD.console_put_char(nil, location[:x], location[:y], char.ord, TCOD::BKGND_SET)
    TCOD.console_set_default_foreground(nil, DEFAULT_SCREEN_FORE_COLOR)
    TCOD.console_set_default_background(nil, DEFAULT_SCREEN_BACK_COLOR)
  end

  def map_location_to_screen_location(col_ind, row_ind)
    {x: col_ind+@screen_map_offset_cols,
     y: row_ind+@screen_map_offset_rows}
  end
end

