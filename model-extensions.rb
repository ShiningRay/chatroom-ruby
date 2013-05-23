require 'eventmachine'
require 'chatroom-models'

module Chatroom
	Channels = {}
	class Room
		def channel
			@channel ||= (Channels[name] ||= EM::Channel.new)
		end
	end

	UserConnections = {}
	class User
		def connection
			@connection ||= UserConnections[login] 
		end
		def connection=(c)
			@connection = UserConnections[login] = c
		end
	end	
end
