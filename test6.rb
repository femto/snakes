require 'rubygems'
require 'cramp/controller'

class WelcomeAction < Cramp::Controller::Action
  on_start :send_hello_world

  def send_hello_world
    render "Hello World"
    finish
  end
end

Rack::Handler::Thin.run WelcomeAction, :Port => 3000