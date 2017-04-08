#!/usr/bin/ruby
require "daemons"

server = __dir__ + "/os-user-api.rb"
Daemons.run(server, :dir => "/tmp/", :dir_mode => :normal)
