require 'mysql2'
require 'em-websocket'
require 'json'
require 'yaml'
require 'rubygems'
require 'active_record'
require 'logger'
require 'bcrypt'
require 'rails-erd'
require 'mysql2'
require 'openssl'
require 'base64'
require 'objspace'

VM_OPTIONAL =   0x00001
VM_REQUIRED =   0x00002
VM_NOTALLOW =   0x00004
VM_STRICT   =   0x00008
VM_REGEX_VALIDPATH = '/^\/[\w\d\/-_\s].*/'


LOG_DEBUG	   		=0x00000001
LOG_VERBOSE	    =0x00000002
LOG_DUMP	    	=0x00000004
LOG_FENTRY	    =0x00000008
LOG_EXCEPTION		=0x00000010
LOG_INFO	    	=0x00000020
LOG_WARN    		=0x00000040
LOG_ERROR   		=0x00000080
LOG_VERYVERBOSE	=0x00000100
LOG_FPARAMS 		=0x00000200
LOG_FRETURN 		=0x00000400
LOG_FRPARAM	    =0x00000800
LOG_BACKTRACE   =0x00001000
LOG_MALLOLC		  =0x00002000

SLOG_DUMP_YAML		=0x00000001
SLOG_DUMP_JSON  	=0x00000002
SLOG_DUMP_INSPECT =0x00000004

$logTranslate = {
	LOG_DEBUG => 'D',
	LOG_VERBOSE => 'V',
	LOG_DUMP => 'Y',
	LOG_FENTRY => 'F',
	LOG_EXCEPTION => 'e',
	LOG_INFO => 'I',
	LOG_ERROR => 'E',
	LOG_VERYVERBOSE => "v",
	LOG_FPARAMS => 'P',
	LOG_FRETURN => 'R',
	LOG_FRPARAM => 'r',
}

require 'rails/all'
require 'bundler'
require 'bundler/setup'
Bundler.require(*Rails.groups)
require 'devise/orm/active_record'

puts Gem.loaded_specs.values.map {|x| "#{x.name} #{x.version}"}


Dir["./class*rb"].each { |file|
	puts "Require: " + file
	require file
}
Dir["./testing/*rb.use"].each { |file|
	if File.symlink?(file)
		nFile = File.readlink(file)
		nFile = './testing/' + nFile
	elsif File.file?(file)
		nFile = file
	end

	puts "Require: " + nFile
	require nFile
}

Dir["./models/*rb"].each {| file|
	puts "Require: " + file
	require file
}

Dir["./client_models/*rb"].sort.each { |file|
	puts "Require: " + file
	require file
}

ActiveRecord::Base.logger = Logger.new('/home/carbide/ActiveRecord-debug.log')

configuration = YAML::load(IO.read('config/database.yml'))
#clientconfig = YAML::load(IO.read('../../carbide-client/config/database.yml'))

ActiveRecord::Base.establish_connection(configuration['development'])
#ActiveRecord::Base.establish_connection(clientconfig['development'])

class String
	def is_json?
		begin
			!!JSON.parse(self)
		rescue
			false
		end
	end
end


class ProjectServer
	attr_accessor	:clients
	attr_accessor	:documents
	attr_accessor	:chats
	attr_accessor	:FileTree
	attr_accessor :taskBoards
	attr_accessor :webServer
	public
	def logMsg(logLevel, msg)
		if ((logLevel & @logLevel) == 0 )
			return(false)
		end
		levelStr = String.new
		$logTranslate.each do |key, value|
			if ((logLevel & key) != 0)
				levelStr += value
			end
		end
		levelStr = "%12s" % levelStr
		timeStr = '%.2f' % Time.now.to_f
		threadId = Thread.current.inspect
		callingFunction = caller.first.inspect[/\`(.*)\'/,1]
		callingLine = caller.first.inspect[/line.*(\d+)/,1]
		logMsg = "[#{timeStr}] (#{levelStr}) #{callingFunction}:#{callingLine} (): #{msg}"
		puts logMsg
		if (msg.length > 250)
			puts "MESSAGE TOO LONG!!!!! Truncating for SQL"
			puts YAML.dump(caller)
			msg = msg[0..250]
		end
		sleParams = {
			:entrytime => Time.now,
			:flags => logLevel,
			:source => "#{callingFunction}:#{callingLine}",
			:message => msg}
		if (@sleThreads.count > 10)
			@sleThreads.each do |sleThr|
				sleThr.join
			end
		end
		@sleThreads.delete_if { |thread| !thread.status }

		@sleThreads << Thread.new(sleParams) do
 			ServerLogEntry.create(sleParams)
		end
	end

		def dump(object)
			if (!(@logLevel & LOG_DUMP))
				return("Dump disabled")
			end
			if (@logParams & SLOG_DUMP_YAML == SLOG_DUMP_YAML)
				return(YAML.dump(object))
			elsif (@logParams & SLOG_DUMP_INSPECT == SLOG_DUMP_INSPECT)
				return(object.inspect.to_s)
			elsif (@logParams & SLOG_DUMP_JSON == SLOG_DUMP_JSON)
				return(object.to_json)
			end

		end

		def readTree()
			fsb = DBFSBase.new(@FileTree)
			testlist = fsb.dbbuildTree()
			fsb.dbcreateFileTree(testlist)
			fsb = FileSystemBase.new(@baseDirectory, @FileTree)
			testlist = fsb.buildTree()
			fsb.createFileTree(testlist)
		end

		def registerWebServer(webServer)
			@webServer = webServer
		end

		def initialize(projectName, baseDirectory)
			$Project = self
			@logLevel = 0xFFFFFFFF
			@logLevel = (@logLevel & ~(LOG_FRPARAM))
			@logLevel = (@logLevel & ~(LOG_DUMP))
			@logParams = SLOG_DUMP_INSPECT
			@sleThreads = []
			puts "logLevel: " + "%#b" % "#{@logLevel}"
			@chats = { }
			@clients = { }
			@documents = { }
			@terminals = { }
			@taskBoards = { }
			@webServer = nil
			@projectName = projectName
			@FileTree = FileTreeX.new
			@FileTree.setOptions(projectName, self)
			@baseDirectory = baseDirectory
			readTree()
			for n in 0..0
				#Lots of bash consoles and chats by default to stress test and
				# to check GUI functionality
				addChat('StdDev' + n.to_s)
				addTerminal('Default_Terminal' + n.to_s)
			end
		end

		def start(opts = { })
			EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
				ws.onopen    { addClient(ws) }
				ws.onmessage { |msg| handleMessage(ws, msg) }
				ws.onclose   { removeClient(ws) }
			end
		end

		def handleMessage(ws, msg)
			if (msg.is_json?)
				jsonString = JSON.parse(msg)
				if (jsonString['commandSet'] == 'document')
					puts "This message corresponds to a document"
					if (!jsonString['documentTarget'].nil?)
						docTarget = jsonString['documentTarget']
					elsif (!jsonString['document'].nil?)
						docTarget = jsonString['document']
					elsif (!jsonString['targetDocument'].nil?)
						docTarget = jsonString['targetDocument']
					else
						puts "There was no document or documentTarget in jsonString"
						puts $Project.dump(jsonString)
						return false;
					end

					if (doc = getDocument(docTarget))
						doc.procMsg(getClient(ws), jsonString);
					else
						puts "handleMessage couldn't getDocument() -- document " + docTarget + " doesn't exist as far as we know"
					end
				elsif (jsonString['commandSet'] == 'chat')
					puts "This message corresponds to a chat for #{jsonString['chatTarget']}"
					if (chat = getChat(jsonString['chatTarget']))
						chat.procMsg(getClient(ws), jsonString)
					else
						puts "We should create a new chat since it doesn't exist"
						chat = addChat(jsonString['chatTarget'])
						chat.procMsg(getClient(ws), jsonString)
					end
				elsif (jsonString['commandSet'] == 'FileTree')
					STDERR.puts "Received FileTree command"
					STDERR.flush
					@FileTree.procMsg(getClient(ws), jsonString)
				elsif (jsonString['commandSet'] == 'term')
					if (term = getTerminal(jsonString['termTarget']))
						term.procMsg(getClient(ws), jsonString)
					else
						puts "Asked to process a message for terminal that doesnt exist"
					end
				elsif (jsonString['commandSet'] == 'task')
					if (taskTarget = getTaskBoard(jsonString['taskTarget']))
						taskTarget.procMsg(getClient(ws), jsonString)
					else
						puts "Asked to process a message for a non-existent taskBoard or taskTarget wasn't set!"
						puts $Project.dump(jsonString)
					end
				elsif (!jsonString['commandSet'] || jsonString['commandSet'] == 'base')
					puts "This message is general context"
					if (self.respond_to?("procMsg_#{jsonString['command']}"))
						puts "Found a function handler for  #{jsonString['command']}"
						self.send("procMsg_#{jsonString['command']}", (ws), jsonString);
					elsif
						puts "There is no function to handle the incoming command #{jsonString['command']}"
					end
				elsif (jsonString['commandSet'] == 'client')
					puts "Got a client message"
					puts $Project.dump(jsonString)
				else
					puts "Unrecognized commandSet or commandSet unset"
					if (jsonString['commandSet'])
						puts "Command set: #{jsonString['commmandSet']}"
					end
				end
			elsif
				puts "Message was either invalid JSON or another format"
			end
		end



		def getTerminal(termName)
			puts "getTerminal called with #{termName}"
			if (@terminals[termName])
				return @terminals[termName];
			end
			return FALSE
		end

		def procMsg_authenticateUser(ws, msg)

		end

		def procMsg_createChatRoom(ws, msg)
			hash = 0
			createChatRoomValidation = {
				'hash' => {
					'classNames' => 'String',
					'reqBits' => VM_OPTIONAL | VM_STRICT,
				},
				'createChatRoom' => {
					'classNames' => 'Hash',
					'reqBits' => VM_REQUIRED | VM_STRICT,
					'subObjects' => {
						'chatRoomName' => {
							'classNames' => 'String',
							'reqBits' => VM_REQUIRED | VM_STRICT,
							'matchExp' => '/^[\w\d-_\s]+$/'
						}
					}
				}
			}
			vMsg = validateMsg(createChatRoomValidation, msg)
			if (!vMsg['status'])
				generateError(ws, hash, vMsg['status'], vMsg['errorReasons'], 'openTerminal')
				return false
			end

			createChat = msg['createChatRoom']
			chatName = createChat['chatRoomName']

			if (!getChat(chatName))
				addChat(chatName)
			end

			replyObject = {
				'status' => 'true',
				'hash' => msg['hash'],
				'createChatRoom' => createChat,
			}

			replyString = replyObject.to_json
			sendToClient(@clients[ws], replyString)
			return(true)
		end

		def procMsg_createTerminal(ws,msg)
			hash = 0
			createTerminalValidation = {
				'hash' => {
					'classNames' => 'String',
					'reqBits' => VM_OPTIONAL | VM_STRICT,
				},
				'createTerminalBoard' => {
					'classNames' => 'Hash',
					'reqBits' => VM_REQUIRED | VM_STRICT,
					'subObjects' => {
						'terminalName' => {
							'classNames' => 'String',
							'reqBits' => VM_REQUIRED | VM_STRICT,
							'matchExp' => '/^[\w\d-_\s]+$/'
						}
					}
				}
			}
			vMsg = validateMsg(createTaskBoardValidation, msg)
			if (!vMsg['status'])
				generateError(ws, hash, vMsg['status'], vMsg['errorReasons'], 'openTerminal')
				return false
			end

			createTerminal = msg['createTerminal']
			termName = createTerminal['terminalName']

			if (!getTerminal(termName))
				addTerminal(termName)
			end

			replyObject = {
				'status' => 'true',
				'hash' => msg['hash'],
				'createTerminal' => createTerminal,
			}
			replyString = replyObject.to_json
			sendToClient(@clients[ws], replyString)

			return(true)
		end

		def procMsg_createTaskBoard(ws, msg)
			hash = 0
			createTaskBoardValidation = {
				'hash' => {
					'classNames' => 'String',
					'reqBits' => VM_OPTIONAL | VM_STRICT,
				},
				'createTaskBoard' => {
					'classNames' => 'Hash',
					'reqBits' => VM_REQUIRED | VM_STRICT,
					'subObjects' => {
						'taskBoardName' => {
							'classNames' => 'String',
							'reqBits' => VM_REQUIRED | VM_STRICT,
							'matchExp' => '/^[\w\d-_\s]+$/'
						}
					}
				}
			}
			vMsg = validateMsg(createTaskBoardValidation, msg)
			if (!vMsg['status'])
				generateError(ws, hash, vMsg['status'], vMsg['errorReasons'], 'openTerminal')
				return false
			end

			createTaskBoard = msg['createTaskBoard']
			boardName = createTaskBoard['taskBoardName']

			if (!getTaskBoard(boardName))
				addTaskBoard(boardName)
			end

			replyObject = {
				'status' => 'true',
				'hash' => msg['hash'],
				'createTaskBoard' => createTaskBoard,
			}
			replyString = replyObject.to_json
			sendToClient(@clients[ws], replyString)
			return(true)
		end


		def procMsg_openTerminal(ws,msg)
			hash = 0
			openTerminalValidation = {
				'hash' => {
					'classNames' => 'String',
					'reqBits' => VM_OPTIONAL | VM_STRICT,
				},
				'openTerminal' => {
					'classNames' => 'Hash',
					'reqBits' => VM_REQUIRED | VM_STRICT,
					'subObjects' => {
						'termName' => {
							'classNames' => 'String',
							'reqBits' => VM_REQUIRED | VM_STRICT,
							'matchExp' => '/^[\w\d-_\s]+$/'
						}
					}
				}
			}
			vMsg = validateMsg(openTerminalValidation, msg)
			if (!vMsg['status'])
				generateError(ws, hash, vMsg['status'], vMsg['errorReasons'], 'openTerminal')
				return false
			end

			openTerminal = msg['openTerminal']
			termName = openTerminal['termName']
			puts "procMsg Open Terminal #{termName}"

			if (!getTerminal(termName))
				puts "Creating terminal"
				addTerminal(termName)
			end
			client = @clients[ws]
			client.addTerminal(getTerminal(termName))
			@terminals[termName].addClient(client, ws)
		end

		def generateError(ws, hash, status, errorReasons, commandRequested)
			clientReply = {
				'hash' => hash,
				'status' => status,
				'errorReasons' => errorReasons,
				'commandSet' => 'reply',
				'commandType' => commandRequested,
			}
			puts $Project.dump(clientReply)
			puts "Converting to json.."
			clientString = clientReply.to_json
			puts clientString
			puts "Sending to client!"
			sendToClient(@clients[ws], clientString)
			return false
		end

		def procMsg_closeTerminal(ws,msg)
		end

		def procMsg_openDocument(ws, msg)
			docName = msg["documentName"]
			client = @clients[ws]
			client.addDocument(docName)
			@documents[docname].addClient(client)
		end

		def procMsg_closeDocument(ws, msg)
		end

		def procMsg_hintActiveDocument(ws, msg)
		end

		def procMsg_getFileTree(ws, msg)
			return(@fileTree.getFileTreeJSON(ws, msg))
		end

		def procMsg_getChatList(ws, msg)
			names = chatNames()
			clientReply = {
				'commandSet' => 'reply',
				'commandType' => 'chat',
				'command' => 'getChatList',
				'getChatList' => {
					'status' => true,
					'chatList' => names,
				},
			}
			clientString = clientReply.to_json

			sendToClient(@clients[ws], clientString)
		end

		def validateMsg(validation, msg)
			begin
				puts "Enter validateMsg"
				errorReasons = []
				validation.each {|key, val|
					puts "Key: #{key}, VAL:"
					puts $Project.dump(val)
					if (val['reqBits'] & VM_REQUIRED)
						puts "VM_REQUIRED for #{key}"
						if (!msg.has_key?(key))
							puts "Msg has no key #{key}"
							errorReasons << 'Missing required key: {#key}'
						elsif (val.has_key?('classNames') && !(msg[key].class.name == val['classNames']))
							puts "Msg has invalid clasName!"
							className = msg[key].class.name
							errorReasons << "Invalid class type: #{className}, should be #{val['classNames']}"
						else
							puts "Msg has key and proper className"
							# Everything is OK, check subObjects if they exist!
							begin
								if (val.has_key?('classNames') && val['classNames'] == "Hash" && val.has_key?('subObjects'))
									puts "classNames == Hash && val.has_key subOjects, call validateMsg() recursively"
									subValidation = validateMsg(val['subObjects'], msg[key])
									puts "validateMsg() recursive call complete"
									if (!subValidation['status'])
										if (subValidation['errorReasons'].count)
											subValidation['errorReasons'].each{|reason|
												errorReasons << reason
											}
										else
											puts "There were no errorReasons but subValidation['status'] was false.."
										end
									end
								end
							rescue Exception => e
								puts "There was an error!"
								puts $Project.dump(e)
								puts "Error: " + e.message
								puts "Backtrace: " + e.backtrace
								errorReasons << ['EXCEPTION! #{e.message}']
								errorReasons.count ? myStatus = true : myStatus = false
								return({'status' => myStatus, 'errorReasons' => errorReasons})
							end
						end
					end
				}
			rescue Exception => e
				puts "There was an error!"
				puts $Project.dump(e)
				puts "Error: " + e.message
				puts "Backtrace: " + e.backtrace
				errorReasons << ['EXCEPTION! #{e.message}']
				errorReasons.count ? myStatus = true : myStatus = false
				return({'status' => myStatus, 'errorReasons' => errorReasons})
			end
			errorReasons.count ? myStatus = true : myStatus = false
			return({'status' => myStatus, 'errorReasons' => errorReasons})
		end

		def procMsg_downloadDocument(ws, msg)
			puts "Enter procMsg_downloadDocument"
			puts "JSON: " + msg.to_json
			downloadDocumentValidation = {
				'hash' => {
					'classNames' => 'String',
					'reqBits' => VM_OPTIONAL | VM_STRICT,
				},
				'downloadDocument' => {
					'classNames' => 'Hash',
					'reqBits' => VM_REQUIRED | VM_STRICT,
					'subObjects' => {
						'srcPath' => {
							'classNames' => 'String',
							'matchExp' => VM_REGEX_VALIDPATH,
							'reqBits' => VM_REQUIRED | VM_STRICT,
						},
					},
				},
			}

			hash = 0
			if (msg.has_key?('hash'))
				puts "Msg has hash!"
				hash = msg['hash']
			end
			vMsg = validateMsg(downloadDocumentValidation, msg);
			if (!vMsg['status'])
				generateError(ws, hash, vMsg['status'], vMsg['errorReasons'], 'downloadDocument')
				return false
			end

			downloadDocument = msg['downloadDocument']
			srcPath = downloadDocument['srcPath']
			httpLink = @webServer.getBaseURL + '/download' + "?srcPath=#{srcPath}"

			clientReply = {
				'hash' => hash,
				'status' => true,
				'errorReasons' => false,
				'commandSet' => 'reply',
				'commandType' => 'downloadDocument',
				'downloadDocument' => {
					'httpLink' => httpLink,
				},
			}
			clientString = clientReply.to_json
			sendToClient(@clients[ws], clientString)
			puts "Sent to client: " + clientString
			return true
		end

		def procMsg_getTaskBoardListJSON(ws = false, jsonMsg = false)
			counter = 0;
			jsonString = [
				'id' => 'taskboardroot',
				'parent' => '#',
				'text' => 'Task Boards',
				'type' => 'root',
				'li_attr' => {
					'class' => 'jsRoot',
				},
			]
			@taskBoards.each { |key, c|
				puts "taskBoards.each: taskName is " + c.taskName
				counter = counter + 1
				myJSON = {
					'id' => c.taskName,
					'parent' => 'taskboardroot',
					'text' => c.taskName,
					'type' => 'taskBoard',
					'li_attr' => {
						"class" => 'jsTreeTaskBoard',
					},
				}
				jsonString << myJSON
			}
			if (ws != false)
				jsonString = jsonString.to_json
				clientReply = {
					'commandSet' => 'taskBoard',
					'command' => 'setTaskBoardTreeJSON',
					'setTaskBoardTreeJSON' => {
						'taskBoardTree' => jsonString,
					}
				}
				clientString = clientReply.to_json
				sendToClient(@clients[ws], clientString)
				return true
			end
			$Project.dump(jsonString);
			return true
		end


		def procMsg_getChatListJSON(ws = false, jsonMsg = false)
			counter = 0;
			jsonString = [
				'id' => 'chatroot',
				'parent' => '#',
				'text' => 'Chat Rooms',
				'type' => 'root',
				'li_attr' => {
					'class' => 'jsRoot',
				},
			]
			@chats.each { |key, c|
				puts "Chats.each: roomName is " + c.roomName
				counter = counter + 1
				myJSON = {
					'id' => c.roomName,
					'parent' => 'chatroot',
					'text' => c.roomName,
					'type' => 'chat',
					'li_attr' => {
						"class" => 'jsTreeChat',
					},
				}
				jsonString << myJSON
			}
			if (ws != false)
				jsonString = jsonString.to_json
				clientReply = {
					'commandSet' => 'chat',
					'command' => 'setChatTreeJSON',
					'setChatTreeJSON' => {
						'chatTree' => jsonString,
					}
				}
				clientString = clientReply.to_json
				sendToClient(@clients[ws], clientString)
				return true
			end
			$Project.dump(jsonString);
			return true
		end

		def procMsg_getTermListJSON(ws = false, jsonMsg = false)
			counter = 0;
			jsonString = [
				'id' => 'terminalroot',
				'parent' => '#',
				'text' => 'Terminals',
				'type' => 'root',
				'li_attr' => {
					'class' => 'jsRoot',
				},
			]
			@terminals.each { |key, c|
				myJSON = {
					'id' => c.termName,
					'parent' => 'terminalroot',
					'text' => c.termName,
					'type' => 'terminal',
					'li_attr' => {
						"class" => 'jsTreeTerminal',
					},
				}
				jsonString << myJSON
			}
			if (ws != false)
				#			jsonString = jsonString.to_json
				clientReply = {
					'commandSet' => 'term',
					'command' => 'setTermTreeJSON',
					'setTermTreeJSON' => {
						'termTree' => jsonString,
					}
				}
				clientString = clientReply.to_json
				sendToClient(@clients[ws], clientString)
				return true
			end
			$Project.dump(jsonString);
			return true
		end



		def addDocument(documentName, dbEntry = nil)
			$Project.logMsg(LOG_FENTRY, "Called")
			document = Document.new(self, documentName, @baseDirectory, dbEntry);
			if (dbEntry)
				$Project.logMsg(LOG_DEBUG | LOG_MALLOC, "dbEntry ObjectSpace.memsize_of(): " + $Project.dump(ObjectSpace.memsize_of(dbEntry)))
				$Project.logMsg(LOG_DEBUG | LOG_MALLOC, "Document memsize_of(): " + $Project.dump(ObjectSpace.memsize_of(document)))
				rval = dbEntry.calcCurrent()
				data = rval[:data].encode("UTF-8", invalid: :replace, undef: :replace, replace: '')
				document.setContents(data)
				dbEntry = nil
				$Project.logMsg(LOG_DEBUG | LOG_MALLOC, "dbEntry ObjectSpace.memsize_of(): " + $Project.dump(ObjectSpace.memsize_of('dbEntry')))
				$Project.logMsg(LOG_DEBUG | LOG_MALLOC, "Document memsize_of(): " + $Project.dump(ObjectSpace.memsize_of(document)))
			end
			@documents[documentName] = document
			return getDocument(documentName)
		end

		def getDocument(documentName, autoCreate = false)
			if (@documents[documentName])
				return @documents[documentName];
			end
			#puts "Invalid document name: #{documentName}"
			return FALSE
		end

		def addTerminal(termName)
			puts "addTerm called with #{termName}"
			term = Terminal.new(self, termName);
			@terminals[termName] = term;
			myJSON = {
				'commandSet' => 'term',
				'command' => 'addTerm',
				'addTerm' => {
					'node' => {
						'id' => termName,
						'parent' => 'terminalroot',
						'text' => termName,
						'type' => 'terminal',
						'li_attr' => {
							"class" => 'jsTreeTerminal',
						}
					}
				}
			}
			sendAll(myJSON.to_json)
			return (getTerminal(termName))
		end


		def addChat(chatName)
			chat = ChatChannel.new(self, chatName)
			@chats[chatName] = chat
			myJSON = {
				'commandSet' => 'chat',
				'command' => 'addChat',
				'addChat' => {
					'node' => {
						'id' => chatName,
						'parent' => 'chatroot',
						'text' => chatName,
						'type' => 'chat',
						'li_attr' => {
							"class" => 'jsTreeChat',
						}
					}
				}
			}
			sendAll(myJSON.to_json)
			return getChat(chatName)
		end


		def getChat(chatName)
			if (@chats[chatName])
				return @chats[chatName];
			end
			puts "Invalid chatroom name: #{chatName}"
			return FALSE
		end

		def addTaskBoard(boardName)
			board = TaskBoard.new(self, boardName)
			@taskBoards[boardName] = board
			myJSON = {
				'commandSet' => 'taskBoard',
				'command' => 'addTaskBoard',
				'addTaskBoard' => {
					'node' => {
						'id' => boardName + "_TB",
						'parent' => 'taskboardroot',
						'text' => boardName,
						'type' => 'taskBoard',
						'li_attr' => {
							"class" => 'jsTreeTaskBoard',
						}
					}
				}
			}
			sendAll(myJSON.to_json)
			return (boardName)
		end



		def getTaskBoard(boardName)
			puts "getTaskBoard called with #{boardName}"
			if (@taskBoards[boardName])
				return @taskBoards[boardName];
			end
			return FALSE
		end


		def getClient(ws)
			if (@clients[ws])
				return(@clients[ws])
			elsif
				puts "Invalid client with socket: #{ws}"
				return FALSE
			end
		end

		def addClient(ws)
			client = Client.new(ws);
			client.name = assignName("User");
			@clients[ws] = client;
		end

		def removeClient(ws)
			$Project.logMsg(LOG_INFO, "Removing client -- informing listeners of this event")
			client = @clients[ws]
			$Project.logMsg(LOG_DEBUG | LOG_DUMP, $Project.dump(client))
			$Project.logMsg(LOG_INFO, "Iterating through client.terms.each")

			client.chats.each do |key, value|
				$Project.logMsg(LOG_DEBUG | LOG_DUMP, $Project.dump(key))
				$Project.logMsg(LOG_DEBUG | LOG_DUMP, $Project.dump(value))
				$Project.logMsg(LOG_INFO, "Remove client #{client.name} from Chat #{value.termName}")
				value.remClient(client)
			end

			$Project.logMsg(LOG_INFO, "Iterating through client.terms.each")
			client.terms.each do |key, value|
				$Project.logMsg(LOG_DEBUG | LOG_DUMP, $Project.dump(key))
				$Project.logMsg(LOG_DEBUG | LOG_DUMP, $Project.dump(value))
				$Project.logMsg(LOG_INFO, "Remove client #{client.name} from Terminal #{value.termName}")
				value.remClient(client)
			end
			client = @clients.delete(ws);
		end

		def sendToClients(type, info)
			sendAll(info)
		end

		def sendToClientsListeningExcept(oclient, document, msg)
			@clients.each do |websocket, client|
				if (oclient != client && client.listeningToDocument(document))
					websocket.send msg
				end
			end
		end

		def sendToClientsListeningExceptWS(ws, document, msg)
			@clients.each do |websocket, client|
				if (!(websocket == ws) && client.listeningToDocument(document))
					websocket.send msg
				else
					puts "sendToClientsListeningExceptWS(): Skipping client"
				end
			end
		end

		def sendToClientsExcept(oclient, msg)
			@clients.each do |websocket, client|
				if (oclient != client)
					websocket.send msg
				end
			end
		end

		def sendAll(msg)
			@clients.each do |websocket, client|
				websocket.send msg
			end
			puts "Sent to all: #{msg}"
		end

		def sendToClient(client, msg)
			if (client.websocket)
				client.websocket.send msg
			else
				client.send msg
			end
		end

		def chatNames
			@chats.collect{|key, c| c.name}.sort
		end

		def clientNames
			@clients.collect{|websocket, c| c.name}.sort
		end

		def assignName(rName)
			existing_names = self.clientNames
			if existing_names.include?(rName)
				i = 1
				while existing_names.include?(rName + i.to_s)
					i+= 1
				end
				rName += i.to_s
			end
			puts "New client connected: #{rName}"
			return rName
		end
	end


	puts "First line of code to run"
	baseDirectory = File.expand_path(File.dirname(__FILE__) + "/../../")
	puts "Using directory " + baseDirectory
	$Project = ProjectServer.new('CARBIDE-SERVER', baseDirectory)
	@myProject = $Project
	@webServer = WebServer.new('0.0.0.0', 'alpha0.carb-ide.com', 6400, baseDirectory)
	Thread.abort_on_exception = false

	myProjectThread = Thread.new {
		@myProject.start()
	}
	puts "Registering myProject with webServer"
	@webServer.registerProject(@myProject)


	webServerThread = Thread.new {
		@webServer.start()
		puts $Project.dump(myWebServer)
	}
	puts "All done! Now we gogogo!"

	@myProject.registerWebServer(@webServer)


	puts webServerThread.status
	puts myProjectThread.status

	while true do
		if (!webServerThread.alive? || !myProjectThread.alive?)
			puts "WS Status: " + webServerThread.status.to_s
			puts "Project Status: " + myProjectThread.status.to_s
			puts "A thread has died."
			webServerThread.exit
			myProjectThread.exit
			exit
		end
		sleep 1
	end

	webServerThread.exit
	myProjectThread.exit
	@DEH = DirectoryEntryHelper.new()


	@DEH.setOptions('CARBIDE-SERVER', myProject)


	if (false && (newDirectories.count > 0))
		newDirectories.each do |d|
			a = DirectoryEntryHelper.create(d)
			puts $Project.dump(d[:owner])
		end
	end

	if (false && (newFiles.count > 0))
		puts "newFiles.each do.."
		newFiles.each do |d|
			@DEH.create(d)
			puts $Project.dump(d[:owner])
		end
	end

	# subDirs = [
	#   'config',
	#   'db',
	#   'models',
	#   'testing',
	#   'db/migrate',
	# ]
	#
	# puts "Creating directories.."
	# @DEH.mkDir("/server", 1)
	# subDirs.each do |d|
	#   @DEH.mkDir('/server/' + d, 1)
	# end
	puts "New file tree:"
	puts "Testing logins"

	frank = UserController.login({:email => 'frankd412@gmail.com', :password => 'bx115'})
	mike = UserController.login({:email => 'mikew@frank-d.info', :password => 'mikew'})
	john = UserController.login({:email => 'john@frank-d.info', :password => 'badpassword'})

	puts "There are " + User.count.to_s + " users in the database"
	puts "There are " + DirectoryEntry.count.to_s + " file descriptors in the database"
