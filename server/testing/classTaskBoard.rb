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
    if (!getClient(client.websocket) && jsonMsg['taskCommand'] != 'joinTask')
      puts "Client has not formally joined the Task -- this is OK in alpha state, adding client implicitly"
    end
    if (self.respond_to?("procMsg_#{jsonMsg['taskCommand']}"))
      puts "Found a function handler for  #{jsonMsg['taskCommand']}"
      self.send("procMsg_#{jsonMsg['taskCommand']}", client, jsonMsg);
    elsif
      puts "There is no function to handle the incoming command #{jsonMsg['taskCommand']}"
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

  def procMsg_createTaskColumn(client, jsonMsg)
    createTaskColumn = jsonMsg['createTaskColumn']
    createTaskColumn['status'] = true
    createTaskColumn['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'createTaskColumn',
      'hash' => jsonMsg['hash'],
      'createTaskColumn' => createTaskColumn,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_createTaskRow(client, jsonMsg)
    createTaskRow = jsonMsg['createTaskRow']
    createTaskRow['status'] = true
    createTaskRow['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'createTaskRow',
      'hash' => jsonMsg['hash'],
      'createTaskRow' => createTaskRow,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_deleteTaskColumn(client, jsonMsg)
    deleteTaskColumn = jsonMsg['deleteTaskColumn']
    deleteTaskColumn['status'] = true
    deleteTaskColumn['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'deleteTaskColumn',
      'hash' => jsonMsg['hash'],
      'deleteTaskColumn' => deleteTaskColumn,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_deleteTaskRow(client, jsonMsg)
    deleteTaskRow = jsonMsg['deleteTaskRow']
    deleteTaskRow['status'] = true
    deleteTaskRow['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'deleteTaskRow',
      'hash' => jsonMsg['hash'],
      'deleteTaskRow' => deleteTaskRow,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_moveTaskRow(client, jsonMsg)
    moveTaskRow = jsonMsg['moveTaskRow']
    moveTaskRow['status'] = true
    moveTaskRow['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'moveTaskRow',
      'hash' => jsonMsg['hash'],
      'moveTaskRow' => moveTaskRow,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_moveTaskColumn(client, jsonMsg)
    moveTaskColumn = jsonMsg['moveTaskColumn']
    moveTaskColumn['status'] = true
    moveTaskColumn['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'moveTaskColumn',
      'hash' => jsonMsg['hash'],
      'moveTaskColumn' => moveTaskColumn,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_changeCellColor(client, jsonMsg)
    changeCellColor = jsonMsg['changeCellColor']
    changeCellColor['status'] = true
    changeCellColor['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'changeCellColor',
      'hash' => jsonMsg['hash'],
      'changeCellColor' => changeCellColor,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_createTask(client, jsonMsg)
    createTask = jsonMsg['createTask']
    createTask['status'] = true
    createTask['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'createTask',
      'hash' => jsonMsg['hash'],
      'createTask' => createTask,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_moveTask(client, jsonMsg)
    moveTask = jsonMsg['moveTask']
    moveTask['status'] = true
    moveTask['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'moveTask',
      'hash' => jsonMsg['hash'],
      'moveTask' => moveTask,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_addTaskTitle(client, jsonMsg)
    taskAddTitle = jsonMsg['taskAddTitle']
    taskAddTitle['status'] = true
    taskAddTitle['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'taskAddTitle',
      'hash' => jsonMsg['hash'],
      'taskAddTitle' => taskAddTitle,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_remoteTaskTitle(client, jsonMsg)
    taskRemoveTitle = jsonMsg['taskRemoveTitle']
    taskRemoveTitle['status'] = true
    taskRemoveTitle['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'taskRemoveTitle',
      'hash' => jsonMsg['hash'],
      'taskRemoveTitle' => taskRemoveTitle,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_addTaskText(client, jsonMsg)
    taskAddText = jsonMsg['taskAddText']
    taskAddText['status'] = true
    taskAddText['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'taskAddText',
      'hash' => jsonMsg['hash'],
      'taskAddText' => taskAddText,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_deleteTask(client, jsonMsg)
    deleteTask = jsonMsg['deleteTask']
    deleteTask['status'] = true
    deleteTask['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'deleteTask',
      'hash' => jsonMsg['hash'],
      'deleteTask' => deleteTask,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_changeTaskBG(client, jsonMsg)
    changeTaskBG = jsonMsg['changeTaskBG']
    changeTaskBG['status'] = true
    changeTaskBG['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'changeTaskBG',
      'hash' => jsonMsg['hash'],
      'changeTaskBG' => changeTaskBG,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_addTaskNote(client, jsonMsg)
    addTaskNote = jsonMsg['addTaskNote']
    addTaskNote['status'] = true
    addTaskNote['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'addTaskNote',
      'hash' => jsonMsg['hash'],
      'addTaskNote' => addTaskNote,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_updateTaskNote(client, jsonMsg)
    taskNoteUpdate = jsonMsg['taskNoteUpdate']
    taskNoteUpdate['status'] = true
    taskNoteUpdate['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'taskNoteUpdate',
      'hash' => jsonMsg['hash'],
      'taskNoteUpdate' => taskNoteUpdate,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end

  def procMsg_deleteTaskNote(client, jsonMsg)
    deleteTaskNote = jsonMsg['deleteTaskNote']
    deleteTaskNote['status'] = true
    deleteTaskNote['errorReasons'] = false
    clientReply = {
      'commandSet' => 'taskBoard',
      'commandReply' => true,
      'taskCommand' => 'deleteTaskNote',
      'hash' => jsonMsg['hash'],
      'deleteTaskNote' => deleteTaskNote,
    }
    clientString = clientReply.to_json
    sendToClient(client, clientString)
  end
end
