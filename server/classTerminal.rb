require 'pty'
require 'yaml'
require 'io/console'
require 'termios'







class TerminalBase
		
	attr_accessor	:clients
		
	attr_accessor	:termName
		

	def initialize(project, termName)
		$Project.logMsg(LOG_FENTRY, "Entering function")
		$Project.logMsg(LOG_FPARAMS, "project:" + YAML.dump(project))
		$Project.logMsg(LOG_FPARAMS, "termName: #{termName}")
		@project = project
		@termName = termName
		@clients = { }
		@sizes = { }
		$Project.logMsg(LOG_INFO, "Terminal term #{termName} initialized")
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
		$Project.logMsg(LOG_INFO, "Launched new thread: " + YAML.dump(@po))
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
		$Project.logMsg(LOG_FENTRY, "Called")
		if (@clients[ws])
			$Project.logMsg(LOG_WARN, "This client already exists for this terminal #{@termName}")
			return false
		end
		if (getClientByName(client.name))
			$Project.logMsg(LOG_WARN, "This client already exists for this terminal #{@termName}")
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

		clientString = clientPropagate.to_json
		$Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "Propagating message to client: " + clientString)
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
	    $Project.logMsg(LOG_FENTRY, "Called")
		client.removeTerm(@termName)
		if (@clients[client.websocket])
		    @clients.delete(client.websocket)
		else
		    $Project.logMsg(LOG_WARN, "Client was not in the list..")
		end
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

	def sendToClients(msg)
		$Project.logMsg(LOG_FENTRY, "Called")
		$Project.logMsg(LOG_FPARAMS, "msg: " + msg)
		t = []
		ccnt = @clients.count
		$Project.logMsg(LOG_INFO | LOG_VERBOSE, "Sending message to #{ccnt} clients -- msg: #{msg}")
		@clients.each do |websocket, client|
			t << Thread.new do
				$Project.logMsg(LOG_DEBUG, "Launched new thread to send message to client")
				websocket.send msg
			end
		end
		t.each do |thread|
			$Project.logMsg(LOG_DEBUG, "Rejoining a send message thread")
			thread.join
		end
	end


	def sendToClient(client, msg)
		$Project.logMsg(LOG_FENTRY, "Called")
		client.websocket.send msg
	end

	def resizeSelf()
		$Project.logMsg(LOG_FENTRY, "Called")
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
		$Project.logMsg(LOG_INFO, "Resizing terminal to #{minX}x#{minY}")
	end

end

class Terminal < TerminalBase
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

	def procMsg_inputChar(client, jsonMsg)
		inputChar = jsonMsg['inputChar']
		@input.print(inputChar['data'])
		broadcastReply = {
			'commandSet' => 'term',
			'commandReply' => true,
			'command' => 'clientInput',
			'terminal' => @termName,
			'clientInput' => {
				'userName' => client.name,
			}
		}
		clientString = broadcastReply.to_json
		sendToClients(clientString)
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
		resizeSelf()
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