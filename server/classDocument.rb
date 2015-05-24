class DocumentBase

  attr_accessor :name
  attr_accessor :project
  attr_accessor :clients
  
  def initialize(project, name)
    @project = project
    @name = name
    @revision = 0
    @data = Array.new(1, "");
    @data.insert(' ');
    @clients = { };
  end

  def addClient(client, ws)
    @clients[ws] = client
  end

  def remClient(ws)
    @clients.delete(ws)
  end

  def getCurrentRevision()
    return @revision
  end

  def getRevisionData(revision)
    if (revision == @revision)
    return @data
    else
      puts "This is NYI behavior -- #{revision} does not match #{@revision}"
    return 0
    end

  end

  def getHash(revision)
    @myString = @data.join('\n')
    puts "We should generate a hash here for this string: #{@myString}"
    return 0xFF
  end

end

class Document < DocumentBase
  def procMsg(client, jsonMsg)
    puts "Asked to process a message for myself: #{name} from client #{client.name}"
    if (self.respond_to?("procMsg_#{jsonMsg['command']}"))
      puts "Found a function handler for  #{jsonMsg['command']}"
      self.send("procMsg_#{jsonMsg['command']}", client, jsonMsg);
    elsif
    puts "There is no function to handle the incoming command #{jsonMsg['command']}"
    end
  end

  def procMsg_getContents(client, jsonMsg)
    @data.each { |d|
      if (d.is_a?(String))
        d = d.sub("\n","").sub("\r","")
      end
    }

    @clientReply = {
			'commandSet' => 'document',
			'command' => 'documentSetContents',
			'targetDocument' => @name,
			'documentSetContents' => {
				'documentRevision' => @revision,
				'numLines' => @data.length,
				'docHash' => getHash(@revision),
				'data' => @data.join("\n"),
				'document' => @name,
			}
		}
    @clientString = @clientReply.to_json
    @project.sendToClient(client, @clientString)
    puts "getContents(): Called #{jsonMsg}"
    puts "Returning:"
    puts @clientReply

  end

  def procMsg_getInfo(client, jsonMsg)
    @clientReply = {
			'replyType' => 'reply_getInfo',
			'documentInfo' => {
				'documentRevision' => @revision,
				'numLines' =>  @data.length,
				'docHash' => getHash(@revision),
			}
		}
    @clientString = @clientReply.to_json
    @project.sendToClient(client, @clientString)
    puts "getInfo(): Called #{jsonMsg}"
    puts "Returning:"
    puts @clientReply
  end

  def sendMsg_cInsertDataSingleLine(client, document, line, data, char, length, ldata)
    @clientReply = {
			'commandSet' => 'document',
			'command' => 'insertDataSingleLine',
			'targetDocument' => document,
			'insertDataSingleLine' => {
				'status' => TRUE,
				'hash' => 0xFF,
				'line' => line,
				'data' => data,
				'char' => char,
				'length' => length,
				'ldata' => ldata,
				'document' => document,
			},
			#Temporary, each command should come in with a hash so we can deal with fails like this and rectify them
		}
    @clientString = @clientReply.to_json
    @project.sendToClientsListeningExceptWS(client.websocket, document, @clientString)
  end

  def sendMsg_cDeleteDataSingleLine(client, document, line, data, char, length, ldata)
    @clientReply = {
			'commandSet' => 'document',
			'command' => 'deleteDataSingleLine',
			'targetDocument' => document,
			'deleteDataSingleLine' => {
				'status' => TRUE,
				'hash' => 0xFF,
				'sourceUser' => client.name,
				'line' => line,
				'data' => data,
				'char' => char,
				'length' => length,
				'ldata' => ldata,
				'document' => document,
			},
			#Temporary, each command should come in with a hash so we can deal with fails like this and rectify them
		}
    @clientString = @clientReply.to_json
    @project.sendToClientsListeningExceptWS(client.websocket, document, @clientString)

  end

  def sendMsg_cInsertDataMultiLine(client, document, startLine, startChar, length, data)
    @clientReply = {
			'commandSet' => 'document',
			'command' => 'insertDataMultiLine',
			'targetDocument' => name,
			'insertDataMultiLine' => {
				'status' => TRUE,
				'hash' => 0xFF,
				'sourceUser' => client.name,
				'startLine' => startLine,
				'startChar' => startChar,
				'numLines' => length,
				'data' => data,
				'document' => document,
			},
			#Temporary, each command should come in with a hash so we can deal with fails like this and rectify them
		}
    @clientString = @clientReply.to_json
    @project.sendToClientsListeningExceptWS(client.websocket, document, @clientString)
  end

  def procMsg_insertDataMultiLine(client, jsonMsg)
    startLine = jsonMsg['insertDataMultiLine']['startLine'].to_i
    n_startLine = startLine
    data = jsonMsg['insertDataMultiLine']['data']
    startChar = jsonMsg['insertDataMultiLine']['startChar'].to_i
    length = data.length
    puts "insertDataMultiLine(): Called #{jsonMsg}"

    if (@data[startLine].nil?)
    @data.push(data[0].to_str);
    else
      str = @data.fetch(startLine).to_str
      if str.length < startChar
        a = str.length;
        while (a < startChar)
          a = str.length
          str.insert(a, " ")
          a += 1
        end

        puts "#{str.length} is less than #{char}.. this may crash"
      end
      str.insert(startChar, data[0])
      @data.fetch(startLine, str)
      puts "OK! " + @data.fetch(startLine)
    end

    puts data[1..-1].inspect
    data[1..-1].each do |cline|
      startLine = startLine + 1
      puts cline
      if (@data[startLine].nil?)
      @data.insert(startLine, cline.to_s);
      else
        @data.insert(startLine, cline.to_s);
        puts "Need to write function handler for existing data"
      end
    end
    puts "Done"
    puts @data.inspect
    sendMsg_cInsertDataMultiLine(client, @name, n_startLine, startChar, length, data)
  end
  
  def procMsg_insertDataSingleLineOld(client, jsonMsg)
    line = jsonMsg['insertDataSingleLine']['line'];
    #data = jsonMsg['insertDataSingleLine']['data'][0].gsub("\n","")
    odata = jsonMsg['insertDataSingleLine']['data']
    data = odata.sub("\n", "").sub("\r", "")
    char = jsonMsg['insertDataSingleLine']['ch'].to_i
    
    if (!data.is_a?(String)) 
      puts "Data was not of type string"
      puts data.inspect
    end
    
    length = data.length
    puts "insertDataSingleLine(): Called #{jsonMsg}"

    if (@data[line].nil? || !length)
      @data.insert(line, data.to_str);
    else
      appendToLine(line, char, data)
    end
    
    sendMsg_cInsertDataSingleLine(client, @name, line, odata, char, length, @data[line])

  end
  
  def procMsg_insertDataSingleLine(client, jsonMsg)
    line = jsonMsg['insertDataSingleLine']['line'];
    #data = jsonMsg['insertDataSingleLine']['data'][0].gsub("\n","")
    odata = jsonMsg['insertDataSingleLine']['data']
    data = odata.sub("\n", "").sub("\r", "")
    char = jsonMsg['insertDataSingleLine']['ch'].to_i

    if (!data.is_a?(String))
      puts "Data was not of type string"
      puts data.inspect
    end
    puts "YAML @data"
    puts YAML.dump(@data)
    length = data.length
    puts "insertDataSingleLine(): Called #{jsonMsg}"
    puts "Odata is: " + odata.inspect
    if ((odata == "\n" || odata == '\n'))
      puts "odata is a newline.."
      if (char == 0)
        @data.insert(line, "")
        sendMsg_cInsertDataSingleLine(client, @name, line, odata, char, length, @data[line])
        return true
      end
      myStr = @data.fetch(line)
      if (!myStr)
        puts "There was no existing data, just insert lines"
        myStr = ""
        @data.insert(line, myStr)
        @data.insert(line+1, myStr)
        puts "YAML @data"
        puts YAML.dump(@data)
        sendMsg_cInsertDataSingleLine(client, @name, line, odata, char, length, @data[line])
        return true
      end
      begStr = myStr[0..(char - 1)]
      endStr = myStr[(char)..-1]
      puts "endStr is " + endStr.inspect      
      puts "begStr is " + begStr.inspect
      puts "@data.fetch(line) before change is " + @data.fetch(line).to_s
      puts "Write begstr to " + line.to_s
      @data.delete_at(line)
      @data.insert(line, begStr)
      #@data.fetch(line, begStr)
      puts "@data.fetch(line) after change is " + @data.fetch(line).to_s
      if (endStr)
        puts "Write endstr to " + (line + 1).to_s
        @data.insert((line + 1), endStr)
      else
        puts "Insert empty string at " + (line + 1).to_s
        @data.insert((line + 1), "")
      end
      puts "data.fetch(line) is " + @data.fetch(line).to_s
      puts "data.fetch(line + 1) is " + @data.fetch(line + 1).to_s
      puts "YAML @data"
      puts YAML.dump(@data)
      sendMsg_cInsertDataSingleLine(client, @name, line, odata, char, length, @data[line])
      return true
    end

    if (@data[line].nil?)
      @data.insert(line, data.to_str);
    else
      appendToLine(line, char, data)
    end

    sendMsg_cInsertDataSingleLine(client, @name, line, odata, char, length, @data[line])

  end

  def appendToLine(line, char, data)
    str = @data.fetch(line)
    if (!str)
      return false
    end
    if str.length < char
      a = str.length;
      while (a < char)
        a = str.length
        str.insert(a, " ")
        a += 1
      end

      puts "#{str.length} is less than #{char}.. this may crash"
    end
    str.insert(char, data)
    @data.fetch(line, str)
    puts "OK! " + @data.fetch(line)
  end

  # This is almost done, needs some tweaks!
  def procMsg_deleteDataSingleLine(client, jsonMsg)
    line = jsonMsg['deleteDataSingleLine']['line'].to_i
    data = jsonMsg['deleteDataSingleLine']['data'].to_s
    char = jsonMsg['deleteDataSingleLine']['ch'].to_i
    length = data.length
    deleteDataSingleLine(client, line,data,char,length)
  end

  def procMsg_deleteDataMultiLine(client, jsonMsg)
    ml = jsonMsg['deleteDataMultiLine']
    startChar = ml['startChar'].to_i
    startLine = ml['startLine'].to_i
    endChar = ml['endChar'].to_i
    endLine = ml['endLine'].to_i
    lineData = ml['data']
    i = startLine
    while (i < endLine)
      @data.delete_at(startLine)
      i += 1
    end
    sendMsg_cDeleteDataMultiLine(client, @name, ml)
  end

  def sendMsg_cDeleteDataMultiLine(client, document, ml)
    ml['document'] = document;
    ml['sourceUser'] = client.name;
    puts YAML.dump(ml)
    clientReply = {
      'commandSet' => 'document',
      'command' => 'deleteDataMultiLine',
      'targetDocument' => name,
      'deleteDataMultiLine' => ml,
      #Temporary, each command should come in with a hash so we can deal with fails like this and rectify them
    }
    puts YAML.dump(clientReply)
    clientString = clientReply.to_json
    puts YAML.dump(clientString)
    @project.sendToClientsListeningExceptWS(client.websocket, document, clientString)

  end

  def sendMsg_cDeleteLine(client, document, line)
    @clientReply = {
      'commandSet' => 'document',
      'command' => 'deleteLine',
      'targetDocument' => name,
      'deleteLine' => {
        'status' => TRUE,
        'sourceUser' => client.name,
        'document' => document,
        'line' => line,
      },
      #Temporary, each command should come in with a hash so we can deal with fails like this and rectify them
    }
    @clientString = @clientReply.to_json
    @project.sendToClientsListeningExceptWS(client.websocket, document, @clientString)

  end

  def deleteDataSingleLine(client, line,data,char,length)
    puts "deleteDataSingleLine(): Called  .. deleting " + data.inspect
    if (@data[line].nil?)
      puts "Error: Delete character on line that doesn't exist"
      #client.sendMsg_Fail('deleteDataSingleLine');
      return FALSE
    end
    if (data === "\n")
      puts YAML.dump(@data)
      #@data.fetch(line, @data.fetch(line).slice!(char))
      if (@data.length > (line + 1))
        oldLine = @data.fetch(line) + @data.fetch(line+1)
        @data.delete_at(line)
        @data.insert(line, oldLine)
        #@data.(line, @data.fetch(line) + @data.fetch(line + 1))
        puts "Deleting line at " + (line + 1).to_s
        @data.delete_at(line + 1)
      end
      puts YAML.dump(@data)
      sendMsg_cDeleteDataSingleLine(client, @name, line, data, char, length, @data[line])
    return true
    end
    @str = @data.fetch(line).to_str
    @substr = @str[char..(char + length - 1)]
    puts "Substr calculated to be " + @substr.inspect

    if (@substr == data)
      if (char > 0)
        @begstr = @str[0..(char - 1)]
        @endstr = @str[(char + length)..(@str.length)]
      else
        @begstr = ""
        @endstr = @str[(char + length)..(@str.length)]
      end
      if (!(@endstr.nil? || @begstr.nil?))
        @str = @begstr + @endstr
      else
        if (!@begstr.nil? && @endstr.nil?)
          @str = @begstr
        elsif (!@endstr.nil? && @begstr.nil?)
          @str = @endstr
        else
          @str = ""
        end
      end

      @data[line] = @str
      puts "OK! " + @substr + " should match " +  data
      puts "New string is " + @str
      puts @data.fetch(line, @str)
      sendMsg_cDeleteDataSingleLine(client, @name, line, data, char, length, @data[line])
      return TRUE
    else
      puts "Deleted data #{data} did not match data at string position #{char} with length #{length}! Server reports data is #{@substr}"
      #client.sendMsg_Fail('deleteDataSingleLine');
      return FALSE
    end

  end

  def procMsg_insertLine(client, jsonMsg)
  end

  def procMsg_deleteLine(client, jsonMsg)
  end

  def procMsg_deleteMultiLine(client, jsonMsg)
  end

  def procInput(line, char, data, revision)
    puts "Called with #{line} #{char} #{data} #{revision}"
    if (@revision == revision)
      puts "Revision same, no OT required"
      if !@data[line]
        puts "This is a new line"
      @data.push(data)
      else
        puts "This line exists"
        if (!@data.fetch(line).nil?)
        @data.fetch(line, @data.fetch(line).insert(char, data))
        #puts @data.fetch(line)
        else

        @data.fetch(line, @data.fetch(line).insert(char, data))
        #puts @data.fetch(line)
        end

      end
      @revision += 1
      return TRUE
    else
      puts "We need OT in this case, failure -- was #{revision}, but we have #{@revision}"
      return FALSE
    end
  end

end
