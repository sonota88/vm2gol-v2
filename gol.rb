# coding: utf-8

$w = 8
$h = 6
$grid = []
$buf = []

# init
(0...$h).each {|y|
  $grid[y] = []
  $buf[y] = []
}

(0...$h).each {|y|
  (0...$w).each {|x|
    puts "#{x} #{y}"
    $grid[y][x] = 0
    $buf[y][x] = 0
  }
}

def dump
  (0...$h).each {|y|
    puts $grid[y].map {|v|
      v == 0 ? " " : "@"
    }.join("")
  }
  puts "--------"
end

def make_next_gen
  (0...$h).each {|y|
    (0...$w).each {|x|
      xl = (x == 0) ? $w - 1 : x - 1
      xr = (x == $w - 1) ? 0 : x + 1
      yt = (y == 0) ? $h - 1 : y - 1
      yb = (y == $h - 1) ? 0 : y + 1

      n = 0
      n += $grid[yt][xl]
      n += $grid[y ][xl]
      n += $grid[yb][xl]
      n += $grid[yt][x ]
      n += $grid[yb][x ]
      n += $grid[yt][xr]
      n += $grid[y ][xr]
      n += $grid[yb][xr]

      if $grid[y][x] == 0
        if n == 3
          $buf[y][x] = 1
        else
          $buf[y][x] = 0 # 死んだまま
        end
      else
        if n <= 1
          $buf[y][x] = 0
        elsif n >= 4
          $buf[y][x] = 0
        else
          $buf[y][x] = 1
        end
      end
    }
  }
end

def replace_with_buf
  (0...$h).each {|y|
    (0...$w).each {|x|
      $grid[y][x] = $buf[y][x]
    }
  }
end

$grid[0][0] = 1
$grid[0][1] = 1
$grid[0][2] = 1
$grid[1][2] = 1
$grid[2][1] = 1


loop do
  make_next_gen()
  replace_with_buf()

  dump
  sleep 0.1
end
