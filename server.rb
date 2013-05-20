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
		attr_accessor :user, :user_action, :subscription

		def logged_in?
			!!user
		end

		def opened
			
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
					send_data error: 'login failed' unless logged_in?
				else
					send_data error: 'please login first'
				end
			end
		rescue 
			puts $!.message
			puts $!.backtrace.join("\n")
			send_data error: 'fatal error'
		end

		def send_data(*messages)
			send(*messages.collect{|i|MultiJson.dump(i)})
		end

		def on_close
			user_action.quit
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



class ChatApp
  def call(env)
    body = <<-body
    <html>
    <head>
    <title>aaaaaa</title>
    </head>
    <body>
<script src="http://cdn.sockjs.org/sockjs-0.2.1.min.js"></script>

<script>
  var sock = new SockJS(window.location.href+"chat");

  sock.onopen = function() {
    console.log("open");
  };

  sock.onmessage = function(e) {
    console.log("message", e.data);
  };

  sock.onclose = function() {
    console.log("close");
  };
</script> </body></html>   
    body
    headers = {
      "Content-Type" => "text/html; charset=UTF-8",
      "Content-Length" => body.bytesize.to_s
    }

    [200, headers, [body]]
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
  run ChatApp.new
end

EM.synchrony {
	thin = Rack::Handler.get('thin')
	thin.run(app.to_app, Port: 10000)
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
}
irb_t.join
end