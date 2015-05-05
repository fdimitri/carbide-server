require 'pty'
require 'yaml'
require 'io/console'

class TerminalBase
	attr_accessor	:clients
	attr_accessor	:terminalName
	
	def initialize(project, terminalName)
		@project = project
		@roomName = terminalName
		@clients = { }
		puts "Terminal room #{terminalName} initialized"
		@output, @input, @pid = PTY.spawn("/bin/bash -l")
		po = Thread.new {
			while 1 do
           	     @output.each_char { |c|
           	             sendToClientsChar(c)
           	     }
           	 end
        }	
	end

	def procMsg_inputChar(client, msg)
		
	end
	
STDIN.raw!
po = Thread.new {
        while 1 do
                output.each_char { |c|
                        print c
                }
        end
}
hin = Thread.new {
        while 1 do
                a = STDIN.getc
                input.print a
        end
}


hin.join
po.join
	