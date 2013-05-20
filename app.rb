require 'rubygems'
require 'bundler/setup'
$: << File.expand_path(File.dirname(__FILE__))
require 'eventmachine'
require 'chatroom-models'
require 'model-extensions'

module Chatroom

class ChatTelnetServer <	EM::Connection
	include EM::Protocols::LineText2#LineAndTextProtocol
	attr_accessor :user, :subscription
	def post_init
		@logged_in = false
	end
	def receive_line(line)
		data = line.split
		puts '-------------'
		if user
			puts user.login
			p user.room
		end
		p data

		if logged_in?
			case data[0]
			when 'join'
				room = Room.with(:name, data[1]) || Room.create(name: data[1])
				room.join(user)
				self.user.send_message("joined #{room.name}")
			when 'say'
			else
				user.send_message error: 'unrecognized instruction'
			end
		else
			self.user = User.with(:login, data[0])
			self.user ||= User.create login: data[0], name: data[1]
			self.user.connection = self
			self.user.send_message(info: 'welcome')
		end
	end

	def logged_in?
		!!self.user
	end

	def send_data(*items)
		super items.collect{|i| MultiJson.dump(i)}.join("\r\n")
	end

	def unbind
		super
		if self.user and self.user.room
			puts 'unbind'
			self.user.room.leave(user)
		end
	end
end
end

if $0 == __FILE__

require 'irb'
 
module IRB # :nodoc:
  def self.start_session(binding)
    unless @__initialized
      args = ARGV
      ARGV.replace(ARGV.dup)
      IRB.setup(nil)
      ARGV.replace(args)
      @__initialized = true
    end
 
    workspace = WorkSpace.new(binding)
 
    irb = Irb.new(workspace)
 
    @CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
    @CONF[:MAIN_CONTEXT] = irb.context
 
    catch(:IRB_EXIT) do
      irb.eval_input
    end
    EM.stop
  end
end

irb_t = Thread.new {
  IRB.start_session(binding)
}

EM.run {
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }

	EM.start_server '0.0.0.0', 10000, Chatroom::ChatTelnetServer
}
irb_t.join
end