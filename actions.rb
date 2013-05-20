module Chatroom
	class UserAction
		attr_accessor :user
		def initialize(user)
			self.user = user
		end

    def quit
      user.room.leave(self) if user.room
      #user.connection.close
    end

    def say(data)
			if user.room
				user.room.broadcast(event: 'say', source: user.login, data: data)
			else
				user.send_message(error: 'you havent join a room yet')
			end      
    end

    def join(room_name)
    	room = Room.with(:name, room_name) || Room.create(name: room_name)
      room.join(user)
    end
	end
end