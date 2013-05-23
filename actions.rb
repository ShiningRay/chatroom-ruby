module Chatroom
	class UserAction
		attr_accessor :user
    class Query
      attr_accessor :user
      def initialize(user)
        self.user = user
      end
    end
		def initialize(user)
			self.user = user
		end

    def quit
      user.room.leave(user) if user.room
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

    def query(query_name)
      case query_name
        
      when 'users_in_room'
        if user.room
          user.send_message result: user.room.users.to_hash
        else
          user.send_message error: 'you have not joined a room'
        end
      when 'rooms'
        user.send_message result: Room.all.collect{|r| r.name}
      end
    end
	end
end