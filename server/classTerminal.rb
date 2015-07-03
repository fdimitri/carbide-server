require 'pty'
require 'yaml'
require 'io/console'
require 'termios'


class TerminalBase
	attr_accessor	:clients
	attr_accessor	:termName
	
	def initialize(project, termName)
		@project = project
		@termName = termName
		@clients = { }
		@sizes = { }
		puts "Terminal term #{termName} initialized"
		@output, @input, @pid = PTY.spawn("/bin/bash -l")
		@po = Thread.new {
			while 1 do
				begin
					buffer = @output.read_nonblock(1024)
				rescue IO::WaitReadable
						IO.select([@output])
						retry
				end
				sendToClientsChar(buffer)
           	     #@output.each_char { |c|
          	     #        sendToClientsChar(c)
           	     #}
           	 end
        }	
        resizeSelf()
	end

	def sendToClientsChar(c)
		termMsg = {
			'commandSet' => 'term',
			'command' => 'putChar',
			'terminal' => @termName,
			'putChar' => {
				'data' => c,
			},
		}
		clientString = termMsg.to_json
		sendToClients(clientString)
	end

	def getClient(ws)
		if (@clients[ws])
			return(@clients[ws])
		elsif
			puts "Invalid client with socket: #{ws}"
			return FALSE
		end
	end
	
	def getClientByName(name)
		@clients.each do |websocket, client|
			if (client.name == name)
				return(client)
			end
		end
		return false
	end
	
	def getClientNames
		@clients.collect{|websocket, c| c.name}.sort
	end
	
	def addClient(client, ws)
		puts "Terminal addClient called"
		if (@clients[ws]) 
			puts "This client already exists"
		end
		if (getClientByName(client.name))
			puts "This client already exists by name"
			return false
		end
		@clients[ws] = client 
		clientPropagate = {
			'commandSet' => 'term',
			'command' => 'userJoin',
			'terminal' => @termName,
			'userJoin' => {
				'user' => client.name,
			},
		}
		puts "Propogate message: "
		puts clientPropagate.inspect
		clientString = clientPropagate.to_json
		sendToClients(clientString)
		clientMessage = { 
			'commandSet' => 'term',
			'command' => 'userList',
			'userList' => {
				'list' => getClientNames(),
				'term' => @termName,
			},
		}
		sendToClient(client, clientMessage.to_json)
	end
	
	def remClient(client)
	  client.removeTerm(@termName)
		@clients.delete(client.websocket)
		termMsg = {
			'commandSet' => 'term',
			'command' => 'userLeave',
			'userLeave' => {
	        		'term' => @termName,
			        'user' => client.name,
			},
		}
		clientString = termMsg.to_json
		sendToClients(clientString)
	end
	
	def procMsg(client, jsonMsg)
		puts "Asked to process a message for myself: #{@termName} from client #{client.name}"
		if (!getClient(client.websocket) && jsonMsg['command'] != 'join')
			puts "Client has not formally joined the channel -- this is OK in alpha state, adding client implicitly"
		end
		if (self.respond_to?("procMsg_#{jsonMsg['command']}"))
			puts "Found a function handler for  #{jsonMsg['command']}"
			self.send("procMsg_#{jsonMsg['command']}", client, jsonMsg);
		elsif
			puts "There is no function to handle the incoming command #{jsonMsg['command']}"
		end
	end
	
	def sendToClients(msg)
		t = []
		ccnt = @clients.count
		puts "Sending msg to #{ccnt} clients"
		@clients.each do |websocket, client|
			t << Thread.new do
				puts "Thread launched to send message"
				websocket.send msg
			end
		end
		t.each do |thread|
			puts "Rejoining send message thread"
			thread.join
		end
	end

	
	def sendToClient(client, msg)
		puts "Sending message to client " + msg.inspect
		client.websocket.send msg
	end
	
	def resizeSelf()
		minX = 1000
		minY = 1000
		@sizes.each do |client, size|
			if (size['cols'] < minY)
				minY = size['cols']
			end
			if (size['rows'] < minX)
				minX = size['rows']
			end
		end
		@input.ioctl(Termios::TIOCSWINSZ, [minX,minY,minX,minY].pack("SSSS"))
		puts "Resizing terminal to #{minX}x#{minY}"
	end

end
	
class Terminal < TerminalBase
	def procMsg_inputChar(client, jsonMsg)
		inputChar = jsonMsg['inputChar']
		@input.print(inputChar['data'])
	end

	def procMsg_leaveTerminal(client, jsonMsg)
		remClient(client) 
		clientReply = {
			'commandSet' => 'term',
			'commandReply' => true,
			'command' => 'leaveTerminal',
			'leaveTerminal' => {
					'status' => TRUE,
			}
		}
		clientString = clientReply.to_json
		sendToClient(client, clientString)		
		@sizes.delete(client)
	end

	def procMsg_resizeTerminal(client, jsonMsg)
		puts "procMsg_resizeTerminal called"
		resizeTerminal = jsonMsg['resizeTerminal']
		termSize = resizeTerminal['termSize']
		if (termSize['rows'] && termSize['cols'])
			@sizes[client] = termSize
			resizeSelf()
		else
			puts "There was no termsize rows/cols.."
			puts YAML.dump(jsonMsg)
		end
	end

end