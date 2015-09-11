class TaskBoard
  attr_accessor	:clients
  attr_accessor	:taskName

  def initialize(project, taskName)
    @project = project
    @taskName = taskName
    @clients = { }
    puts "TaskBoard #{taskName} initialized"
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
    if (@clients[ws])
      puts "This client already exists"
    end
    if (getClientByName(client.name))
      puts "This client already exists by name"
      return false
    end
    @clients[ws] = client
    clientPropagate = {
      'commandSet' => 'taskBoard',
      'command' => 'userJoin',
      'userJoin' => {
        'taskBoard' => @taskName,
        'user' => client.name,
      },
    }
    clientString = clientPropagate.to_json
    sendToClients(clientString)
    clientMessage = {
      'commandSet' => 'taskBoard',
      'command' => 'userList',
      'userList' => {
        'list' => getClientNames(),
        'taskBoard' => @taskName,
      },
    }
    sendToClient(client, clientMessage.to_json)
  end

  def remClient(client)
    client.removeTask(@taskName)
    @clients.delete(client.websocket)
    taskMsg = {
      'commandSet' => 'taskBoard',
      'command' => 'userLeave',
      'userLeave' => {
        'taskBoard' => @taskName,
        'user' => client.name,
      },
    }
    clientString = taskMsg.to_json
    sendToClients(clientString)
  end


  def sendToClient(client, msg)
    puts "Sending message to client " + msg.inspect
    client.websocket.send msg
  end

  def sendToClients(msg)
    t = []
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

  def procMsg(client, jsonMsg)
    puts "Asked to process a message for myself: #{@taskName} from client #{client.name}"
    if (!getClient(client.websocket) && jsonMsg['taskCommand'] != 'joinTaskBoard')
      puts "Client has not formally joined the Task -- this is OK in alpha state, adding client implicitly"
    end
    if (self.respond_to?("procMsg_#{jsonMsg['taskCommand']}"))
      puts "Found a function handler for  #{jsonMsg['taskCommand']}"
      self.send("procMsg_#{jsonMsg['taskCommand']}", client, jsonMsg)
    elsif
      puts "There is no function to handle the incoming command #{jsonMsg['taskCommand']} .. using default handler until all functions are written"
      procMsgDefaultHandler(client, jsonMsg)
    end
  end

  def sanitizeMsg(msg)
    return(msg.gsub("<","&lt;").gsub(">","&gt;").gsub('\n', "<br>"))
  end

  def procMsg_joinTask(client, jsonmsg)
    addClient(client, client.websocket)
    client.addTask(self)
  end

  def procMsg_leaveTask(client, jsonmsg)
    remClient(client)
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'command' => 'leaveTask',
      'leaveTask' => {
        'status' => TRUE,
      }
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsgDefaultHandler(client, jsonMsg)
    curCommand = jsonMsg['taskCommand']
    replyObject = jsonMsg[curCommand]
    replyObject['status'] = true
    replyObject['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => curCommand,
      'hash' => jsonMsg['hash'],
      curCommand => replyObject,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end
end
