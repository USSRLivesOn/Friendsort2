class SeamCarver
  
  def initialize(blob)
    @original_img = Magick::ImageList.new
    @original_img.from_blob(blob)
    @original_pixels = img_to_array(@original_img, true)
    @grayscale_img = @original_img.quantize(256, Magick::GRAYColorspace) # Convert to grayscale
    img_with_edges = @grayscale_img.edge(10) # Run through edge detector (proxy for intensity)
    @grayscale_pixels = img_to_array(img_with_edges)
    @energy_map = populate_energy_map(@grayscale_pixels)
  end

  # Carve initialized image to target_height pixels
  def carve(scale)
    scale = [scale, 1.0].min
    target_height = (@original_img.rows * scale).round
    seams_to_cut = [@original_img.rows - target_height, 0].max
    seams_to_cut.times do
      seam = get_lowest_energy_seam(@energy_map)
      remove_seam(@original_pixels, @grayscale_pixels, seam, @energy_map)
    end
    img = array_to_img(@original_pixels, true)
    img.format = 'JPEG'
    img.to_blob
  end

  # Converts img to 2d array of pixels
  def img_to_array(img, color=false)
    mode = color ? 'RGB' : 'I'
    pixels = img.export_pixels(0, 0, img.columns, img.rows, mode)
    if mode == 'RGB'
      merged_pixels = Array.new(pixels.length / 3) { Array.new(3) }
      pixels.each_index do |index|
        merged_pixels[index / 3][index % 3] = pixels[index]
      end
      pixels = merged_pixels
    end
    pixels_2d = Array.new(img.columns) { Array.new(img.rows) }
    0.upto(img.columns - 1) do |col|
      0.upto(img.rows - 1) do |row|
        pixels_2d[col][row] = pixels[row * img.columns + col]
      end
    end
    pixels_2d
  end

  # Converts 2d array of pixels to an image
  # Assumes each nested array is the same length as first one (i.e. 2d array is rectangular)
  def array_to_img(pixel_array, color=false)
    mode = color ? 'RGB' : 'I'
    cols = pixel_array.length
    rows = pixel_array[0].length
    pixels_1d = Array.new(cols * rows)
    0.upto(cols - 1) do |col|
      0.upto(rows - 1) do |row|
        pixels_1d[row * cols + col] = pixel_array[col][row]
      end
    end
    img = Magick::Image.new(cols, rows)
    if mode == 'RGB'
      unmerged_pixels = Array.new()
      pixels_1d.each do |rgb_array|
        rgb_array.each do |rgb_point|
          unmerged_pixels << rgb_point
        end
      end
      pixels_1d = unmerged_pixels
    end
    img.import_pixels(0, 0, cols, rows, mode, pixels_1d)
  end

  # Returns min of arr[x-1][y-1], arr[x-1][y] and arr[x-1][y+1], dealing with edges
  # Returns zero if x = 0 (first column)
  def min_on_left(arr, x, y)
    raise ArgumentError, "x coordinate cannot exceed number of rows" unless x < arr.length
    if x == 0
      0
    else
      raise ArgumentError, "y coordinate cannot exceed length of column (x - 1)" unless y < arr[x-1].length
      if y == 0
        [arr[x-1][y], arr[x-1][y+1]].min
      elsif y == (arr[x-1].length - 1)
        [arr[x-1][y-1], arr[x-1][y]].min
      else
        [arr[x-1][y-1], arr[x-1][y], arr[x-1][y+1]].min
      end
    end
  end

  # Populates energy map (left to right)
  def populate_energy_map(pixels)
    cols = pixels.length
    rows = pixels[0].length
    energy_map = Array.new(cols) { Array.new(rows) }
    energy_map[0] = pixels[0].dup
    1.upto(cols - 1) do |col|
      0.upto(rows - 1) do |row|
        energy_map[col][row] = pixels[col][row] + min_on_left(energy_map, col, row)
      end
    end
    energy_map
  end

  # Returns an array of [col, row] coordinates of the lowest energy seam
  def get_lowest_energy_seam(energy_map)
    lowest_energy = energy_map[energy_map.length - 1].min
    y_coord = energy_map[energy_map.length - 1].index(lowest_energy)
    seam = [[energy_map.length - 1, y_coord]]
    (energy_map.length - 2).downto(0) do |col|
      y_coord = get_index_min_bounded(energy_map[col], y_coord)
      seam << [col, y_coord]
    end
    seam.reverse
  end

  # Returns index of smallest value in col_array within max_offset of current_index
  def get_index_min_bounded(col_array, current_index, max_offset=1)
    min_coord = [current_index - max_offset, 0].max
    min_value = col_array[min_coord]
    range_bottom = min_coord + 1
    range_top = [current_index + max_offset, col_array.length - 1].min
    range_bottom.upto(range_top) do |y_coord|
      if col_array[y_coord] < min_value
        min_coord = y_coord
        min_value = col_array[min_coord]
      end
    end
    min_coord
  end

  # Removes seam from pixels matrix and returns updated energy map
  def remove_seam(original_pixels, grayscale_pixels, seam, energy_map)
    starting_y = seam[0][1]
    seam.each_index do |index|
      x = seam[index][0]
      y = seam[index][1]
      original_pixels[x].delete_at(y)
      grayscale_pixels[x].delete_at(y)
      energy_map[x].delete_at(y)
      min_y = [starting_y - index, 0].max
      max_y = [starting_y + index, grayscale_pixels[index].length - 1].min
      min_y.upto(max_y) do |y|
        energy_map[x][y] = grayscale_pixels[x][y] + min_on_left(energy_map, x, y) 
      end
    end
    energy_map
  end

end
