require 'yaml'

class DungeonLevel
  def initialize(rows, cols)
    #open_map_file("maps/hello.map")
    open_map_file("maps/surrounded.map")
  end
  attr_accessor :cells

  FLOOR_CHAR = '.'
  WALL_CHAR = '#'

  def transparent?(col, row)
    return false if out_of_bounds?(col, row)
    @cells[row][col] != WALL_CHAR
  end

  def walkable?(col, row)
    return false if out_of_bounds?(col, row)
    @cells[row][col] == FLOOR_CHAR
  end

  def player_spawn_point
    point = template_points_for('@').sample
    if point
      # remove from consideration
      @template_cells[point[1]][point[0]] = FLOOR_CHAR
      return point
    else
      [(0...@num_cols).to_a.sample, (0...@num_rows).to_a.sample]
    end
  end

  def monster_spawn_point
    point = template_points_for('x').sample
    if point
      # remove from consideration
      clear_template_cell(point[1], point[0])
      return point
    else
      [(0...@num_cols).to_a.sample, (0...@num_rows).to_a.sample]
    end
  end

  def clear_template_cell(row, col)
    @template_cells[row][col] = FLOOR_CHAR
  end

  def apply_template!
    @cells = []
    @num_rows.times { @cells.push([WALL_CHAR] * @num_cols) }
    @template_cells.each_with_index do |row, row_ind|
      row.each_with_index do |cell, col_ind|
        cell = FLOOR_CHAR if ["x", "@"].include? cell
        @cells[row_ind][col_ind] = cell
      end
    end
  end

  def template_points_for(char)
    points = []
    @template_cells.each_with_index do |row, row_ind|
      row.each_with_index do |cell, col_ind|
        if cell == char
          points.push [col_ind, row_ind]
        end
      end
    end
    points
  end

  private

  def open_map_file(file_path)
    map_definition = YAML.load_file(file_path)
    @num_rows = map_definition["rows"].to_i
    @num_cols = map_definition["cols"].to_i
    @template_cells = map_definition["cells"].map{|row| row.split("")}
  end

  def out_of_bounds?(col, row)
    not in_bounds? col, row
  end

  def in_bounds?(col, row)
    (0 <= col && col < @num_cols) && (0 <= row && row < @num_rows)
  end

  def init_random_level(rows, cols)
    level = []
    rows.times do |row|
      new_row = []
      cols.times do |col|
        if GlobalGameState::PRNG.rand > 0.8
          new_row.push WALL_CHAR
        else
          new_row.push FLOOR_CHAR
        end
      end
      level.push new_row
    end
    level
  end
end

