require 'rubygems'
require 'json'
require 'net/http'
require 'set'

#code by femto
#license under CC license
#please attribute the work and derived work to femto and Siming Educational Facility(http://www.aisiming.com/)


@http = Net::HTTP.new("pythonvsruby.org", 80)

def map
  request = Net::HTTP::Get.new("/room/0/map")

  response = @http.request(request)
  @map = JSON.parse(response.body)

end
def dist(point1, point2)

  x_dist = (point1[0] - point2[0]).abs
  if x_dist > @map['size'][0] /2
    x_dist = (@map['size'][0] - x_dist).abs
  end
  y_dist = (point1[1] - point2[1]).abs
  if y_dist > @map['size'][1] /2
    y_dist = (@map['size'][1]  - y_dist).abs
  end
  x_dist + y_dist
end

def plain_dist(point1, point2)
  x_dist = (point1[0] - point2[0]).abs
  y_dist = (point1[1] - point2[1]).abs
  x_dist + y_dist
end

def info
  request = Net::HTTP::Get.new("/room/0/info")

  response = @http.request(request)
  @info = JSON.parse(response.body)
  
end

def turn

  gems = @info['gems']
  snakes = @info['snakes']
  round = @info["round"]
  me = @info["snakes"][@me["seq"]]

  head = me['body'][0]
  current_direction = @info["snakes"][@me["seq"]]["direction"]

  if current_direction == 0
      available_direction = [0,1,3]
    elsif current_direction == 1
      available_direction = [0,1,2]
    elsif current_direction == 2
      available_direction = [1,2,3]
    elsif current_direction == 3
      available_direction = [0,2,3]
    end
  0.upto(3) do |i|
    if obstacle(head, i)
      available_direction.delete(i) #remove those can't move
    end
  end
  #trying to find the nearest gem

  nearest_gem_index = -1
  gem = gems.min_by do |_gem|
    me_dist = dist(head,_gem)
    other_snakes = snakes.clone
    other_snakes.delete_at(@me["seq"])
    other_snakes = other_snakes.select {|x| x["type"] == "ruby" && x['alive']}
    if !other_snakes.empty?
      other_dist = other_snakes.map {
          |s|dist(s['body'][0],_gem)
      }.min
      if me_dist >= other_dist && other_dist <=3
        me_dist + 999
      else
        me_dist
      end
    else
      me_dist
      end
  end

  if gems.empty? #no gems find
    if obstacle(head, current_direction)
      available_direction=available_direction-[current_direction]
      dir = available_direction[rand(available_direction.size)]
    else
      dir = current_direction
    end
  else
    puts "nearest_gem with dist #{dist(head,gem)},[#{gem[0]},#{gem[1]}], head [#{head[0]},#{head[1]}]"
    path = astar(head, gem)
    #trying to get nearest_gem
    dir = calc_dir(head, path)



    #trying to find a best direction
#    dir = -1
#    if gems[nearest_gem_index][0] > head[0]
#      if available_direction.include?(2) && !obstacle(head, dir)
#        dir = 2
#      else
#        if gems[nearest_gem_index][1] > head[1]
#          if available_direction.include?(3) && !obstacle(head, dir)
#            dir = 3
#          end
#        elsif gems[nearest_gem_index][1] == head[1]
#          dir = current_direction #even we walk left
#        elsif gems[nearest_gem_index][1] < head[1]
#          #try 1
#          if available_direction.include?(1) && !obstacle(head, dir)
#            dir = 1
#          end
#        end
#      end
#    elsif gems[nearest_gem_index][0] == head[0]
#      if gems[nearest_gem_index][1] > head[1]
#          if available_direction.include?(3) && !obstacle(head, dir)
#            dir = 3
#          end
#        elsif gems[nearest_gem_index][1] == head[1]
#          dir = current_direction #shouldn't happen, we already eat it
#        elsif gems[nearest_gem_index][1] < head[1]
#
#          if available_direction.include?(1) && !obstacle(head, dir)
#            dir = 1
#          end
#        end
#    elsif gems[nearest_gem_index][0] < head[0]
#      if available_direction.include?(0) && !obstacle(head, dir)
#        dir = 0
#      else
#        if gems[nearest_gem_index][1] > head[1]
#          if available_direction.include?(3) && !obstacle(head, dir)
#            dir = 3
#          end
#        elsif gems[nearest_gem_index][1] == head[1]
#          dir = current_direction #even we walk right
#        elsif gems[nearest_gem_index][1] < head[1]
#          #try 1
#          if available_direction.include?(1) && !obstacle(head, dir)
#            dir = 1
#          end
#        end
#      end
#    end
    dir = current_direction if dir == -1
    #trying to avoid obstacles in current_dir
    if obstacle(head, dir)
      available_direction=available_direction-[dir]
      dir = available_direction[rand(available_direction.size)]
    else
      #dir = dir
    end



    p "current direction: #{current_direction}"
    puts "to turn direction is #{dir}"
  end #for avaiable gem
  
  request = Net::HTTP::Post.new("/room/#{@roomno}/turn")
  request.set_form_data(:id => @me["id"], :round => @info["round"], :direction => dir)
  response = @http.request(request)
  result = JSON.parse(response.body)
  @turn, @info = result[0], result[1]
  puts "current round: #{@info["round"]}, alive #{@info["snakes"][@me['seq']]['alive']}"
  return @turn, @info
end

def add
  request = Net::HTTP::Post.new("/room/#{@roomno}/add")
  request.set_form_data(:name => "femto", :type => "ruby")
  response = @http.request(request)
  result = JSON.parse(response.body)
  @me, @info = result[0], result[1]
end

def obstacle(head, dir)
  if dir == 2
    x = (head[0] + 1) % @map['size'][0]
    y = head[1]
    return @map['walls'].include?([x,y]) || @info["snakes"].any? {|snake| snake['body'].include?([x,y])} || @info['eggs'].include?([x,y])
  elsif dir == 0
    x = head[0] - 1
    x = @map['size'][0] - 1 if x < 0
    y = head[1]
    return @map['walls'].include?([x,y]) || @info["snakes"].any? {|snake| snake['body'].include?([x,y])} || @info['eggs'].include?([x,y])
  elsif dir == 1
    x = head[0]
    y = head[1] - 1
    y = @map['size'][1] - 1 if y < 0
    return @map['walls'].include?([x,y]) || @info["snakes"].any? {|snake| snake['body'].include?([x,y])} || @info['eggs'].include?([x,y])
  elsif dir == 3

    x = head[0]
    y = (head[1] + 1) %  @map['size'][1]
    return @map['walls'].include?([x,y]) || @info["snakes"].any? {|snake| snake['body'].include?([x,y])} || @info['eggs'].include?([x,y])
  end
end
def astar(start, goal)
  closedset = Set.new
  openset = Set.new([start])
  came_from = {}
  go_for = {}
  g_score = {}
  h_score = {}
  f_score = {}
  g_score[start] = 0
  h_score[start] = dist(start, goal)
  f_score[start] = h_score[start]
  while !openset.empty?

    x = openset.min_by {|node| f_score[node]}
    if x == goal
      return reconstruct_path(came_from, goal)
      #return go_for[start]
    end

    openset.delete(x)
    closedset.add(x)

    neighbors = []
    if !obstacle(x, 0)
      neighbors << left_point(x)
    end
    if !obstacle(x, 2)
      neighbors << right_point(x)
    end
    if !obstacle(x, 1)
      neighbors << upper_point(x)
    end
    if !obstacle(x, 3)
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
                 g_score[y] = tentative_g_score
                 h_score[y] = dist(y, goal)
                 f_score[y] = g_score[y] + h_score[y]
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
@roomno=0

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
  astar([0,0], [3,4])
  exit
end
#test_snake

add
map

while true
begin
  sleep 0.2
  turn
rescue => e
  puts "exception happen"
  puts e.message
  puts e.backtrace.join("\n")
end
end
