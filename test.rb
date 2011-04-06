require 'rubygems'
require 'json'
require 'net/http'

#code by femto
#license under CC license
#please attribute the work and derived work to femto and Siming Educational Facility(http://www.aisiming.com/)


@http = Net::HTTP.new("pythonvsruby.org", 80)

def turn
  current_direction = @info["snakes"][@me["seq"]]["direction"]
  p "current direction: #{current_direction}"
  
  request = Net::HTTP::Post.new("/room/0/turn")
  request.set_form_data(:id => @me["id"], :round => @info["round"], :direction => rand(3))
  response = @http.request(request)
  result = JSON.parse(response.body)
  @turn, @info = result[0], result[1]
end

def add
  request = Net::HTTP::Post.new("/room/0/add")
  request.set_form_data(:name => "RandomRuby", :type => "ruby")
  response = @http.request(request)
  result = JSON.parse(response.body)
  @me, @info = result[0], result[1]
end

add
while true
 sleep 0.2
 turn
end