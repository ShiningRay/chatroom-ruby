require 'rubygems'
require 'bundler/setup'
$: << File.expand_path(File.dirname(__FILE__))
require 'eventmachine'
require 'em-synchrony'
require 'thin'

module Thin
	#class Response
		def self.ruby_18?
			false
		end
	#end
end

require 'sockjs'
require 'chatroom-models'
require 'model-extensions'
require 'rack/sockjs'
require 'actions'

module Chatroom
	class ChatSession < SockJS::Session
		attr_accessor :user, :user_action

		def logged_in?
			!!user
		end

		def opened
			puts 'opened'
		end

		def process_message(message)
			data = MultiJson.load(message)
			p data
			if logged_in? 
				if user_action.respond_to? data['action']
					user_action.send data['action'], data['data']
				else
					send_data error: 'unrecognized action'
				end
			else
				if data['action'] == 'auth'
					auth data['login'], data['name'], ''
          if logged_in?
            send_data event: 'logged_in', data: user.login
          else
            send_data error: 'login failed' 
          end
				else
					send_data error: 'please login first'
				end
			end
		rescue 
			puts $!.message
			puts $!.backtrace.join("\n")
			send_data error: 'unknown error'
		end

		def send_data(*messages)
			send(*messages.collect{|i|MultiJson.dump(i)})
		end

    #patch
    def close(status=3000, message="Go away")
      puts "alive? #{alive?}" rescue nil
      super
    end
    #another patch

		# def after_app_run
  #     puts "alive? #{alive?}"
  #     puts "state? #{current_state}"
		# end

    def on_close
      puts "#{user.name} closed connection" rescue nil
      user_action.quit
      if user.connection && user.connection === self
        user.connection = nil
      end
    end

		def auth(login, name, token)
			self.user = User.with(:login, login) || User.create( login: login, name: name)
			if self.user
				self.user.connection = self
				self.user_action = UserAction.new(self.user)
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

app = ::Rack::Builder.new do
  map '/chat' do
    run ::Rack::SockJS.new(Chatroom::ChatSession)
  end  
  public_dir = File.expand_path('public')
  use Rack::Static, 
    :urls => [""],
    :root => public_dir,
    :index => 'index.html'

  run Rack::File.new(public_dir)
end

EM.synchrony {
  Ohm.connect :driver => :synchrony unless RUBY_PLATFORM =~ /mingw/
  SockJS.debug!
	thin = Rack::Handler.get('thin')
	thin.run(app.to_app, Port: 10000)
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
}
irb_t.join
end