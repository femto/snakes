require 'rubygems'
require 'json'
require 'net/http'
require 'set'

#code by femto
#license under CC license
#please attribute the work and derived work to femto and Siming Educational Facility(http://www.aisiming.com/)

#require 'deep_clone'
#include DeepClone


@http = Net::HTTP.new("pythonvsruby.org", 80)

def map
  request  = Net::HTTP::Get.new("/room/0/map")

  response = @http.request(request)
  @map     = JSON.parse(response.body)

end

def dist(point1, point2)

  x_dist = (point1[0] - point2[0]).abs
  if x_dist > @map['size'][0] /2
    x_dist = (@map['size'][0] - x_dist).abs
  end
  y_dist = (point1[1] - point2[1]).abs
  if y_dist > @map['size'][1] /2
    y_dist = (@map['size'][1] - y_dist).abs
  end
  x_dist + y_dist
end

def descartes_dist(point1, point2)
  x_dist = (point1[0] - point2[0]).abs
  if x_dist > @map['size'][0] /2
    x_dist = (@map['size'][0] - x_dist).abs
  end
  y_dist = (point1[1] - point2[1]).abs
  if y_dist > @map['size'][1] /2
    y_dist = (@map['size'][1] - y_dist).abs
  end
  x_dist * x_dist + y_dist * y_dist
end

def plain_dist(point1, point2)
  x_dist = (point1[0] - point2[0]).abs
  y_dist = (point1[1] - point2[1]).abs
  x_dist + y_dist
end

def info
  request  = Net::HTTP::Get.new("/room/0/info")

  response = @http.request(request)
  @info    = JSON.parse(response.body)

end

def find_food(foods, head, snakes, seq, clever=true, index=0)

  me      = snakes[seq]
  me_type = me["type"]
  if clever
    sort_foods = foods.sort_by do |_food|
      me_dist      = dist(head, _food)
      other_snakes = snakes.clone

      other_snakes.delete_at(seq)
      #同类型的蛇
      other_snakes = other_snakes.select { |x| x["type"] == me_type && x['alive'] }
      if !other_snakes.empty?
        other_dist = other_snakes.map {
            |s| dist(s['body'][0], _food)
        }.min
        if me_dist >= other_dist && other_dist <= 10
          me_dist + 999
        else
          me_dist
        end
      else
        me_dist
      end
    end
    sort_foods[index]
  else
    foods.min_by do |_food|
      descartes_dist(head, _food)
    end
  end
end

def get_available_dirs(info, seq)
  me = info["snakes"][seq]

  if me["type"] == "ruby"
    food_type       = "gems"
    enemy_food_type = "eggs"
  else
    food_type       = "eggs"
    enemy_food_type = "gems"
  end

  available_direction = [0, 1, 2, 3]
  0.upto(3) do |i|
    if obstacle(info, info["snakes"][seq]["body"][0], i, 1, enemy_food_type)
      available_direction.delete(i) #remove those can't move
    end
  end
  available_direction
end

def do_turn_basedon_astar(info, seq, clever=true, log=false)
  snakes = info['snakes']
  round  = info["round"]
  me     = info["snakes"][seq]
  type   = me["type"]
  if type == "ruby"
    food_type       = "gems"
    enemy_food_type = "eggs"
  else
    food_type       = "eggs"
    enemy_food_type = "gems"
  end
  foods               = info[food_type]


  head                = me['body'][0]
  current_direction   = info["snakes"][seq]["direction"]

  available_direction = get_available_dirs(info, seq)
  if (clever)
    if available_direction.empty?
      available_direction1 = []
      #trying to find a less mess dir
      if obstacle(info, head, 0, 1, false)
        available_direction1 << left_point(head)
      end
      if obstacle(info, head, 1, 1, false)
        available_direction1 << upper_point(head)
      end
      if obstacle(info, head, 2, 1, false)
        available_direction1 << right_point(head)
      end
      if obstacle(info, head, 3, 1, false)
        available_direction1 << down_point(head)
      end
      dir = available_direction1[rand(available_direction1.size)]
    end
  end



  if foods.empty? #no gems find
    if obstacle(info, head, current_direction, 1, enemy_food_type)
      available_direction=available_direction-[current_direction]
      dir                = available_direction[rand(available_direction.size)]
    else
      dir = current_direction
    end
  else

    path = nil
    dir = -1
    0.upto(2) do |index|
      food = find_food(foods, head, snakes, seq, true, index)
      if log
        puts "nearest_food with index #{index}, with dist #{dist(head, food)},[#{food[0]},#{food[1]}], head [#{head[0]},#{head[1]}]"
      end
    path = astar(info, head, food, enemy_food_type)

    if path && clever && !trap(info, seq, path, enemy_food_type)
        dir = calc_dir(head, path)
        break
    end
  end
  dir = available_direction[rand(available_direction.size)] if dir == -1
    if log
      p "current direction: #{current_direction}"
      puts "to turn direction is #{dir}"
    end
  end #for avaiable gem


  return path, dir
end

def trap(info, seq, path, enemy_food_type)
  #只考虑5层深
  depth = 5
  if !path.empty?
    live_nodes = Set.new([path.last])
  else
    live_nodes = Set.new([info["snakes"][seq]["body"][0]])
  end
  other_obstacles = path.clone if path
  other_obstacles ||= []
  other_obstacles = other_obstacles.reverse
  other_obstacles = other_obstacles[0..info["snakes"][seq]["body"].size]
  while !live_nodes.empty? && depth >=0
    node = live_nodes.to_a[0]
    live_nodes.delete(node)
    other_obstacles << node

    if !obstacle(info, node, 0, path.length-2, enemy_food_type, other_obstacles)
      live_nodes << left_point(node)
    end
    if !obstacle(info, node, 1, path.length-2, enemy_food_type, other_obstacles)
      live_nodes << upper_point(node)
    end
    if !obstacle(info, node, 2, path.length-2, enemy_food_type, other_obstacles)
      live_nodes << right_point(node)
    end
    if !obstacle(info, node, 3, path.length-2, enemy_food_type, other_obstacles)
      live_nodes << down_point(node)
    end

    depth -= 1
  end
  return live_nodes.size == 0 #if nothing left, consider a trap
end

def turn
  alive_snakes = @info["snakes"].collect { |x| x["alive"] }
#  if @info["snakes"][@me["seq"]]["body"].size >= 8 #alive_snakes.size == 2 && @info["snakes"][@me["seq"]]["alive"] && Set.new(alive_snakes.collect{|x|x["type"]}).size == 2
#    #只有2头蛇，对方蛇跟自己类型不一样，杀戮模式
#    puts "杀戮模式"
#    other_snakes = @info["snakes"].clone
#    other_snakes.delete_at(@me["seq"])
#    other_snake       = other_snakes.max_by { |x| x["body"].size }
#    other_snake_index = @info["snakes"].index(other_snake)
#
#    other_snake       = other_snakes.max_by { |x| x["body"].size }
#    other_path, other_dir = do_turn_basedon_astar(@info, other_snake_index, false, false)
#    path, dir = do_turn_basedon_astar(@info, @me["seq"], true, true)
#
#    val, dir = alphaBeta(@info, 0, 7, Fixnum::MIN, Fixnum::MAX, @me["seq"], other_snake_index, path, other_path)
#
#
#  else
  path, dir = do_turn_basedon_astar(@info, @me["seq"], true, true)

  #end


  request = Net::HTTP::Post.new("/room/#{@roomno}/turn")
  request.set_form_data(:id => @me["id"], :round => @info["round"], :direction => dir)
  response = @http.request(request)
  result   = JSON.parse(response.body)
  @turn, @info = result[0], result[1]
  puts "current round: #{@info["round"]}, alive #{@info["snakes"][@me['seq']]['alive']}"
  return @turn, @info
end

def add
  request = Net::HTTP::Post.new("/room/#{@roomno}/add")
  request.set_form_data(:name => "femto", :type => "ruby")
  response = @http.request(request)
  result   = JSON.parse(response.body)
  @me, @info = result[0], result[1]
end

def snake_obstacle(info, x, y, depth)
  #consider other snake head possible move
  info["snakes"].any? { |snake| snake['body'].include?([x, y]) && (snake['alive'] && snake['body'].index([x, y]) < snake['body'].length-depth || !snake['alive']) }
end

def obstacle(info, head, dir, depth=1, enemy_food_type = "eggs", other_obstacles=nil)
  if dir == 2
    x = (head[0] + 1) % @map['size'][0]
    y = head[1]

  elsif dir == 0
    x = head[0] - 1
    x = @map['size'][0] - 1 if x < 0
    y = head[1]

  elsif dir == 1
    x = head[0]
    y = head[1] - 1
    y = @map['size'][1] - 1 if y < 0

  elsif dir == 3

    x = head[0]
    y = (head[1] + 1) % @map['size'][1]

  end
  if enemy_food_type
    result = @map['walls'].include?([x, y]) || snake_obstacle(info, x, y, depth) || info[enemy_food_type].include?([x, y])
  else
    result = @map['walls'].include?([x, y]) || snake_obstacle(info, x, y, depth)
  end
  if other_obstacles
    result = result || other_obstacles.include?([x, y])
  end
  return result
end

def astar(info, start, goal, enemy_food_type)
  return nil if goal.nil?
  closedset      = Set.new
  openset        = Set.new([start])
  came_from      = {}
  go_for         = {}
  g_score        = {}
  h_score        = {}
  f_score        = {}
  g_score[start] = 0
  h_score[start] = dist(start, goal)
  f_score[start] = h_score[start]
  while !openset.empty?

    x = openset.min_by { |node| f_score[node] }
    if x == goal
      return reconstruct_path(came_from, goal)
      #return go_for[start]
    end

    openset.delete(x)
    closedset.add(x)

    neighbors = []
    if !obstacle(info, x, 0, g_score[x], enemy_food_type)
      neighbors << left_point(x)
    end
    if !obstacle(info, x, 1, g_score[x], enemy_food_type)
      neighbors << upper_point(x)
    end
    if !obstacle(info, x, 2, g_score[x], enemy_food_type)
      neighbors << right_point(x)
    end

    if !obstacle(info, x, 3, g_score[x], enemy_food_type)
      neighbors << down_point(x)
    end


    neighbors.each do |y|
      if closedset.include?(y)
        next
      end
      tentative_g_score = g_score[x] + 1

      if !openset.include?(y)
        openset.add(y)
        tentative_is_better = true
      elsif tentative_g_score < g_score[y]
        tentative_is_better = true
      else
        tentative_is_better = false
      end

      if tentative_is_better = true
        came_from[y] = x
        g_score[y]   = tentative_g_score
        h_score[y]   = dist(y, goal)
        f_score[y]   = g_score[y] + h_score[y]
        #openset.delete(y)
      end


    end

  end
  #else failure
end

def reconstruct_path(came_from, current_node)
  if !came_from[current_node].nil?
    p = reconstruct_path(came_from, came_from[current_node])
    return (p + [current_node])
  else
    return [current_node]
  end
end

def left_point(pt)
  x = pt[0] - 1
  if x < 0
    x = @map['size'][0] - 1
  end
  [x, pt[1]]
end

def right_point(pt)
  x = (pt[0] + 1) % @map['size'][0]
  [x, pt[1]]
end

def upper_point(pt)
  x = pt[0]
  y = pt[1] - 1
  if y < 0
    y = @map['size'][1] - 1
  end
  [x, y]
end

def down_point(pt)
  x = pt[0]
  y = (pt[1] + 1) % @map['size'][1]
  [x, y]
end

def calc_dir(head, path)
  result = -1
  if path && path[1]

    point = path[1]
    puts "calc_dir, head is [#{head[0]},#{head[1]}], point is [#{point[0]},#{point[1]}]"
    if head[0] != point[0]
      if head[0] - point[0] > 0 && head[0] - point[0] < @map['size'][0]/2 || head[0] == 0 && @map['size'][0]/2 < point[0]

        result = 0
      else
        result = 2
      end
    end
    if head[1] != point[1]
      if head[1] - point[1] > 0 && head[1] - point[1] < @map['size'][1]/2 || head[1] == 0 && @map['size'][1]/2 < point[1]
        result = 1
      else
        result = 3
      end
    end

  end
  puts "result is #{result}"
  return result
end

class Fixnum
  N_BYTES = [42].pack('i').size
  N_BITS  = N_BYTES * 8
  MAX     = 2 ** (N_BITS - 2) - 1
  MIN     = -MAX - 1
end

#def evalMax(info, depth)
#best = -Fixnum::MAX;
#if (depth <= 0)
#return Evaluate();
#end
#dirs=[0,1,2]
#dirs.each do |dir|
#info1 = info.clone
#info_snake.move
#val = -evalMax(info, depth - 1); # 注意这里有个负号。
#UnmakeMove();
#if (val > best)
#best = val;
#end
#end
#
#return best;
#end
def get_enemy_food_type(info, seq)
  if info["snakes"][seq]["type"] == "ruby"
    "eggs"
  else
    "gems"
  end
end

#以当前蛇视角进行估值
def evaluation(info, me_seq, other_seq, depth, path)
  if me_seq == @me["seq"]
    if trap(info, other_seq, [], get_enemy_food_type(info, other_seq))
      return 999999
    end
    if path.include?(info["snakes"][me_seq]["body"][0]) && path.index(info["snakes"][me_seq]["body"][0]) == depth
      900
    else
      10
    end
  else #其他蛇的估值函数
    if path.include?(info["snakes"][me_seq]["body"][0]) && path.index(info["snakes"][me_seq]["body"][0]) == depth
      900
    else
      10
    end
  end

end

def get_point(pt, dir)
  if dir == 0
    return left_point(pt)
  elsif dir == 1
    return upper_point(pt)
  elsif dir == 2
    return right_point(pt)
  elsif dir == 3
    return down_point(pt)
  end
end

def alphaBeta(info, depth, max_depth, alpha, beta, me_seq, other_seq, me_path, other_path)
  if (depth >= max_depth)
    return evaluation(info, me_seq, other_seq, depth + 1, me_path);
  end
#　GenerateLegalMoves();
  other_available_dirs = get_available_dirs(info, other_seq)

  #rank for each possible dirs
  if !other_available_dirs.empty?
    other_rank           = -999999
    other_best_dir       = -1
    best_info            = nil
    other_available_dirs = other_available_dirs.each do |dir|
      #info1=info.deep_dup #info.deep_dup
      info1 =Marshal::load(Marshal::dump(info)) #deep_clone

      #move one step

      point = get_point(info1["snakes"][other_seq]["body"][0], dir)

      info1["snakes"][other_seq]["body"].insert(0, point)
      info1["snakes"][other_seq]["body"].pop

      tmp = evaluation(info1, other_seq, me_seq, depth + 1, other_path)
      if other_rank < tmp
        other_rank     = tmp
        other_best_dir = dir
        best_info      = info1
      end

    end
  else #没有可走方向
    return 999999 #对我们很有利
  end

  #make max in front
  #使用info 还是info1?
  me_available_dirs = get_available_dirs(best_info, me_seq)
  #rank for each possible dirs
  best_dir          = nil
  me_available_dirs.each do |dir|
    info2 =Marshal::load(Marshal::dump(best_info)) #deep_clone

    #move one step

    point = get_point(info2["snakes"][me_seq]["body"][0], dir)

    info2["snakes"][me_seq]["body"].insert(0, point)
    info2["snakes"][me_seq]["body"].pop

    val, best_dir0 = alphaBeta(info2, depth + 1, max_depth, alpha, beta, me_seq, other_seq, me_path, other_path);
#    if(val >= beta)
#      return beta;
#    end
    if (val > alpha)
      alpha    = val;
      best_dir = dir
    end
  end
  return alpha, best_dir

#　while (MovesLeft()) {
#　　MakeNextMove();

#　　UnmakeMove();
#　　if (val >= beta) {
#　　　return beta;
#　　}
#　　if (val > alpha) {
#　　　alpha = val;
#　　}
#　}
#　return alpha;
#}
#　
#　　把醒目的部分去掉，剩下的就是最小-最大函数。可以看出现在的算法没有太多的改变。
#　　这个函数需要传递的参数有：需要搜索的深度，负无穷大即Alpha，以及正无穷大即Beta：
#　
#val = AlphaBeta(5, -INFINITY, INFINITY);
end

def setup_test_data
  @map            = {}
  @map['walls']   = []
  @info           = {}
  @info['snakes'] = []
  @info['eggs']   = []
  @map['size']    = [50, 25]
end

def test_snake
  setup_test_data()
  astar(@info, [0, 0], [3, 4])
  exit
end

#test_snake

@roomno=0
add
map

while true
  begin
    sleep 0.15
    turn
  rescue => e
    puts "exception happen"
    puts e.message
    puts e.backtrace.join("\n")
  end
end