DOC_EMPTY =0x00000001

class DocumentBase

  attr_accessor :name
  attr_accessor :project
  attr_accessor :clients

  def initialize(project, name, baseDirectory, dbEntry = nil)
    @project = project
    @name = name
    @revision = 0
    @baseDirectory = baseDirectory
    @clients = { };
    @t = { }
    @rng = Random.new(Time.now.to_i)
    @nonce = @rng.rand(1..9000)
    @dbEntry = dbEntry
    @flags |= DOC_EMPTY
  end

  def unloadDocumentData()
    $Project.logMsg(LOG_FENTRY, "Called")
    @data = nil
    @flags |= DOC_EMPTY
  end

  def loadDocumentData()
    $Project.logMsg(LOG_FENTRY, "Called")
    begin
      if (@dbEntry != nil)
        if (@dbEntry.filechanges.count > 0)
          data = @dbEntry.calcCurrent()
          data = data[:data].encode("UTF-8", invalid: :replace, undef: :replace, replace: '')
          setContents(data)
          data = nil
        end
        $Project.logMsg(LOG_WARN, "There are no fileChange entries for this document")
      end
    rescue Exception => e
      $Project.logMsg(LOG_ERROR | LOG_EXCEPTION, "Rescued from error!")
      $Project.logMsg(LOG_ERROR | LOG_EXCEPTION, $Project.dump(e))
    end
  end

  def addClient(client, ws)
    @clients[ws] = client
  end

  def remClient(ws)
    @clients.delete(ws)
    if (@clients.count == 0 && @data.count > 100)
      unloadDocumentData()
    end
  end

  def getCurrentRevision()
    return @revision
  end

  def getContents
    data = @data.join("\n").encode('UTF-8', invalid: :replace, undef: :replace, replace: '@')
    return data
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
    # This should be something like: myString = dbEntry.getDataByRevision(revision)
    myString = @data.join('\n')
    # puts "We should generate a hash here for this string: #{@myString}"
    digest = getMD5Hash(myString)
    return(digest)
  end

  def getMD5Hash(data)
    if (data.is_a? String)
      digest = OpenSSL::Digest::MD5.hexdigest(data)
      return digest
    end
    puts "Data passed to us for hashing was not a string, we could use .to_s, to_json, or even $Project.dump in this case -- to be determined"
    return false
  end

  def readFromFS()
    fd = File.open(@baseDirectory + @name, "rb");
    if (!fd)
      puts "Failed to open file #{@name}"
      return FALSE
    end
    data = fd.read
    fd.close
    @fsTimeStamp = File.mtime(@baseDirectory + @name)
    @data = data.split(/\n/)
  end

  def writeToFS(thread=false)
    #disable this for now
    #return false
    newTime = File.mtime(@baseDirectory + @name)
    if (newTime != @fsTimeStamp)
      puts "WARNING: Attempting to overwrite file " + @baseDirectory + @name
      puts "WARNING: File has been modified on FS since changes done in editor"
      puts "WARNING: Overwriting FS file changes!"
    else
      puts "Excellent, file has NOT changed since we read it!"
    end

    if (!File.exist?(@baseDirectory + @name))
      $Project.logMsg(LOG_ERROR, "Unable to open file for writing -- doesn't exist")
      return FALSE
    end

    fd = File.open(@baseDirectory + @name, "wb");
    if (!fd)
      puts "Failed to open file #{@name}"
      if (thread)
        raise("Unable to open file #{@name}")
      end
      return FALSE
    end
    fd.write(@data.join("\n"))
    fd.close
    @fsTimeStamp = File.mtime(@baseDirectory + @name)
    if (thread)
      Thread.exit
    end
    return TRUE
  end


  def setContents(data)
    $Project.logMsg(LOG_FENTRY, "Entering function .. data is of class " + data.class.to_s)
    $Project.logMsg(LOG_FPARAMS, "Data: " + $Project.dump(data))
    if (data.is_a?(String))
      data = data.gsub("\r\n","\n").gsub("\r","")
      @data = data.split("\n")
      @flags &= ~DOC_EMPTY
      return(true)
    elsif (data.is_a?(Array))
      if (data.length == 1)
        @data = data.first.split("\n")
      else
        @data = data
      end
      @flags &= ~DOC_EMPTY
      return(true)
    else
      puts "Document::setContents(): Data was not a string or array!?"
      return(false)
    end
  end


end

class Document < DocumentBase
  def procMsg(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called to process a message")
    $Project.logMsg(LOG_FPARAMS, "Client Name: #{client.name} and Message Data: #{jsonMsg.inspect}")
    if (self.respond_to?("procMsg_#{jsonMsg['command']}"))
      puts "Found a function handler for  #{jsonMsg['command']}"
      self.send("procMsg_#{jsonMsg['command']}", client, jsonMsg)
      if (/(insert|delete)/.match(jsonMsg['command']))
        if (@dbEntry.respond_to? ("recvMsg_#{jsonMsg['command']}"))
          @dbEntry.send("recvMsg_#{jsonMsg['command']}", client, jsonMsg)
        else
          puts "dbEntry does not yet respond to recvMsg_#{jsonMsg['command']}"
        end
        if (@t.length)
          puts "Still possibly waiting on " + @t.length.to_s + " threads to write.."
        end
        wait = false
        @t.each_pair do |key, thread|
          puts "Key: " + key.to_s
          puts "Value: " + $Project.dump(thread)
          status = thread.status
          case (status)
          when false
            thread.join
            @t.delete(key)
          when nil
            thread.join
            @t.delete(key)
          when "run"
            puts "Waiting on current write thread before spinning out another one"
            wait = true
          when "sleep"
            puts "Waiting on current write thread before spinning out another one"
            wait = true
          else
            puts "Unknown thread status: " + $Project.dump(status)
          end
        end
        if (wait)
          puts "We were unable to commit these changes to disk due to the last thread not being finished at this time!"
        else
          newThread =  Thread.new{
            writeToFS(true)
          }
          @t.update({Time.now.to_i.to_s + @nonce.to_s => newThread});
          @nonce += 1
        end
      end
    elsif
      puts "There is no function to handle the incoming command #{jsonMsg['command']}"
    end
  end

  def procMsg_getContents(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called")
    begin
      if (@flags & DOC_EMPTY)
        loadDocumentData()
      end

      if (@data && @data.is_a?(Array))
        @data.each { |d|
          if (d.is_a?(String))
            d = d.sub("\n","").sub("\r","")
          else
            $Project.logMsg(LOG_ERROR, "Ran into an error with the data array -- element is not a string. Type is: " + d.class.to_s)
            $Project.logMsg(LOG_ERROR | LOG_DUMP, $Project.dump(d))
            return false
          end
        }
      else
        $Project.logMsg(LOG_ERROR, "@data wasn't an array??")
        $Project.logMsg(LOG_ERROR, $Project.dump(@data))
        clientReply = {
          'commandSet' => 'document',
          'command' => 'documentSetContents',
          'targetDocument' => @name,
          'documentSetContents' => {
            'documentRevision' => @revision,
            'numLines' => 1,
            'docHash' => getHash(@revision),
            'data' => "!!! CARB/IDE ERROR LOADING THIS DOCUMENT !!!\n\nPlease submit a bug report!".encode('UTF-8', invalid: :replace, undef: :replace, replace: '@'),
            'document' => @name,
          }
        }
        puts "procMsg_getContents(): Sending client reply.."
        clientString = clientReply.to_json
        @project.sendToClient(client, clientString)
        return false
      end

      rescue Exception => e
        $Project.logMsg(LOG_ERROR | LOG_EXCEPTION, "There was an exception")
        $Project.logMsg(LOG_ERROR | LOG_EXCEPTION, $Project.dump(e))
      end

      begin
        $Project.logMsg(LOG_INFO, "Creating client reply..")
        clientReply = {
          'commandSet' => 'document',
          'command' => 'documentSetContents',
          'targetDocument' => @name,
          'documentSetContents' => {
            'documentRevision' => @revision,
            'numLines' => @data.length,
            'docHash' => getHash(@revision),
            'data' => @data.join("\n").encode('UTF-8', invalid: :replace, undef: :replace, replace: '@'),
            'document' => @name,
          }
        }
      rescue Exception => e
        puts "There was an error!"
        puts $Project.dump(e)
        puts "Error: " + e.message
        puts "Backtrace: " + e.backtrace
      end

      puts "procMsg_getContents(): Sending client reply.."
      clientString = clientReply.to_json
      @project.sendToClient(client, clientString)
    end

    def procMsg_getInfo(client, jsonMsg)
      clientReply = {
        'replyType' => 'reply_getInfo',
        'documentInfo' => {
          'documentRevision' => @revision,
          'numLines' =>  @data.length,
          'docHash' => getHash(@revision),
        }
      }
      clientString = clientReply.to_json
      @project.sendToClient(client, clientString)
      puts "getInfo(): Called #{jsonMsg}"
      puts "Returning:"
      puts clientReply
    end

    def sendMsg_cInsertDataSingleLine(client, document, line, data, char, length, ldata)
      clientReply = {
        'commandSet' => 'document',
        'command' => 'insertDataSingleLine',
        'targetDocument' => document,
        'insertDataSingleLine' => {
          'status' => TRUE,
          'line' => line,
          'data' => data,
          'char' => char,
          'length' => length,
          'ldata' => ldata,
          'document' => document,
        },
        #Temporary, each command should come in with a hash so we can deal with fails like this and rectify them
      }
      clientString = clientReply.to_json
      clientReply['insertDataSingleLine']['hash'] = getMD5Hash(clientString)
      @project.sendToClientsListeningExceptWS(client.websocket, document, clientString)
    end

    def sendMsg_cDeleteDataSingleLine(client, document, line, data, char, length, ldata)
      clientReply = {
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
      clientString = clientReply.to_json
      @project.sendToClientsListeningExceptWS(client.websocket, document, clientString)

    end

    def sendMsg_cInsertDataMultiLine(client, document, startLine, startChar, length, data)
      clientReply = {
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
      clientString = clientReply.to_json
      @project.sendToClientsListeningExceptWS(client.websocket, document, clientString)
    end

    def procMsg_insertDataMultiLine(client, jsonMsg)
      startLine = jsonMsg['insertDataMultiLine']['startLine'].to_i
      n_startLine = startLine
      data = jsonMsg['insertDataMultiLine']['data']
      startChar = jsonMsg['insertDataMultiLine']['startChar'].to_i
      length = data.length
      rval = do_insertDataMultiLine(client, jsonMsg)
      data = rval['data']
      sendMsg_cInsertDataMultiLine(client, @name, n_startLine, startChar, length, data)
    end

    def do_insertDataMultiLine(client, jsonMsg)
      startLine = jsonMsg['insertDataMultiLine']['startLine'].to_i
      n_startLine = startLine
      data = jsonMsg['insertDataMultiLine']['data']
      startChar = jsonMsg['insertDataMultiLine']['startChar'].to_i
      length = data.length
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
          # puts "#{str.length} is less than #{char}.. this may crash"
        end
        str.insert(startChar, data[0])
        @data.fetch(startLine, str)
        # puts "OK! " + @data.fetch(startLine)
      end

      puts data[1..-1].inspect
      data[1..-1].each do |cline|
        startLine = startLine + 1
        puts cline
        if (@data[startLine].nil?)
          @data.insert(startLine, cline.to_s);
        else
          @data.insert(startLine, cline.to_s);
          # puts "Need to write function handler for existing data"
        end
      end
      return({'success' => 'true', 'data' => data})
    end



    def procMsg_insertDataSingleLine(client, jsonMsg)
      $Project.logMsg(LOG_FENTRY, "Called")
      begin
        $Project.logMsg(LOG_FPARAMS, "Client:\n" + $Project.dump(client))
        $Project.logMsg(LOG_FPARAMS, "jsonMsg type: #{jsonMsg.class.to_s}, dump:\n" + $Project.dump(jsonMsg))
        jsonMsg['hash'] = 0xFF
        hash = 0xFF
        insertDataSingleLineValidation = {
          'hash' => {
            'classNames' => 'String',
            'reqBits' => VM_OPTIONAL | VM_STRICT,
          },
          'insertDataSingleLine' => {
            'classNames' => 'Hash',
            'reqBits' => VM_REQUIRED | VM_STRICT,
            'subObjects' => {
              'type' => {
                'classNames' => 'String',
                'reqBits' => VM_REQUIRED | VM_STRICT,
                'matchExp' => '/.*/'
              },
              'ch' => {
                'classNames' => [ 'String', 'FixNum' ],
                'reqBits' => VM_REQUIRED | VM_STRICT,
              },
              'line' => {
                'classNames' => [ 'String', 'FixNum' ],
                'reqBits' => VM_REQUIRED | VM_STRICT,
              },
              'data' => {
                'classNames' => 'String',
                'reqBits' => VM_REQUIRED | VM_STRICT,
                'matchExp' => '/.*/'
              },
            }
          }
        }
        vMsg = $Project.validateMsg(insertDataSingleLineValidation, jsonMsg)
        if (!vMsg['status'])
          $Project.logMsg(LOG_ERROR, "Unable to validate message")
          $Project.logMsg(LOG_ERROR | LOG_DUMP, $Project.dump(vMsg))
          $Project.generateError(client, hash, vMsg['status'], vMsg['errorReasons'], 'createTerminal')
          return false
        end
        $Project.logMsg(LOG_INFO, "Message successfully validated")
      rescue Exception => e
        puts $Project.dump(e)
        $Project.logMsg(LOG_ERROR, "We had an exception (Section 0x00)!")
        $Project.logMsg(LOG_ERROR, $Project.dump(e))
      end

      begin
        line = jsonMsg['insertDataSingleLine']['line'];
        odata = jsonMsg['insertDataSingleLine']['data']
        data = odata.sub("\n", "").sub("\r", "")
        char = jsonMsg['insertDataSingleLine']['ch'].to_i
        length = data.length
        rval = do_insertDataSingleLine(client, jsonMsg)
        if (!rval)
          $Project.logMsg(LOG_ERROR, "Failed to do_insertDataSingleLine")
          # NOTE: We need to return an error message to the client
          return false
        end

      rescue Exception => e
        puts $Project.dump(e)
        $Project.logMsg(LOG_ERROR, "We had an exception (Section 1)!")
        $Project.logMsg(LOG_ERROR, $Project.dump(e))
      end

      begin
        $Project.logMsg(LOG_INFO, "Sending message to self :sendMsg_cInsertDataSingleLine..")
        $Project.logMsg(LOG_INFO | LOG_DEBUG | LOG_DUMP, $Project.dump(rval))
        params = rval['replyParams']
        self.send(:sendMsg_cInsertDataSingleLine, *params)
      rescue Exception => e
        puts $Project.dump(e)
        $Project.logMsg(LOG_ERROR, "We had an exception (Section 2)!")
        $Project.logMsg(LOG_ERROR, $Project.dump(e))
      end
    end

    def do_insertDataSingleLine(client, jsonMsg)
      $Project.logMsg(LOG_FENTRY, "Called")
      begin
        line = jsonMsg['insertDataSingleLine']['line']
        odata = jsonMsg['insertDataSingleLine']['data']
        data = odata.gsub("\n", "").gsub("\r", "")
        char = jsonMsg['insertDataSingleLine']['ch'].to_i
        length = data.length
        if (!odata.is_a?(String))
          $Project.logMsg(LOG_ERROR, "Data was not of type string, it has class: " + jsonMsg['insertDataSingleLine']['data'].class.to_s)
          return false
        end
        $Project.logMsg(LOG_INFO, "odata is: " + odata.gsub("\n", "\\n").gsub("\r","\\r").inspect)
        # puts "YAML @data"
        # puts $Project.dump(@data)
        # puts "insertDataSingleLine(): Called #{jsonMsg}"
        # puts "Odata is: " + odata.inspect
        if ((odata == "\n" || odata == "\r\n" || odata == "\r"))
          $Project.logMsg(LOG_INFO, "odata was \\n, \\r\\n, or \\r")
          if (char == 0)
            # Beginning of line, just insert a new line
            @data.insert(line, "")
            return ( {'success' => 'true',  'replyParams' => [ client, @name, line, odata, char, length, @data[line] ] } )
          end
          myStr = @data.fetch(line)
          if (!myStr || !myStr.length)
            # There was no data on the line
            # puts "There was no existing data, just insert lines"
            @data.insert(line, "")
            #@data.insert(line+1, myStr) #I think this is incorrect
            # puts "YAML @data"
            # puts $Project.dump(@data)
            return ( {'success' => 'true',  'replyParams' => [ client, @name, line, odata, char, length, @data[line] ] } )
          end
          if (myStr && myStr.length)
            begStr = myStr[0..(char - 1)]
            endStr = myStr[(char)..-1]
            # puts "endStr is " + endStr.inspect
            # puts "begStr is " + begStr.inspect
            # puts "@data.fetch(line) before change is " + @data.fetch(line).to_s
            # puts "Write begstr to " + line.to_s
            @data.delete_at(line)
            @data.insert(line, begStr)
            #@data.fetch(line, begStr)
            # puts "@data.fetch(line) after change is " + @data.fetch(line).to_s
            if (endStr)
              # puts "Write endstr to " + (line + 1).to_s
              @data.insert((line + 1), endStr)
            else
              # puts "Insert empty string at " + (line + 1).to_s
              @data.insert((line + 1), "")
            end
            # puts "data.fetch(line) is " + @data.fetch(line).to_s
            # puts "data.fetch(line + 1) is " + @data.fetch(line + 1).to_s
            # puts "YAML @data"
            # puts $Project.dump(@data)
            return ( {'success' => 'true',  'replyParams' => [ client, @name, line, odata, char, length, @data[line] ] } )
          end
        end

        if (@data[line].nil?)
          @data.insert(line, data.to_str);
        else
          appendToLine(line, char, data)
        end
        return ( {'success' => 'true',  'replyParams' => [ client, @name, line, odata, char, length, @data[line] ] } )
      rescue Exception => e
        $Project.logMsg(LOG_ERROR, "We had an exception!")
        $Project.logMsg(LOG_ERROR | LOG_DUMP, $Project.dump(e))
      end
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
      end
      str.insert(char, data)
      @data.fetch(line, str)
      # puts "OK! " + @data.fetch(line)
    end

    # This is almost done, needs some tweaks!
    def procMsg_deleteDataSingleLine(client, jsonMsg)
      line = jsonMsg['deleteDataSingleLine']['line'].to_i
      data = jsonMsg['deleteDataSingleLine']['data'].to_s
      char = jsonMsg['deleteDataSingleLine']['ch'].to_i
      length = data.length
      deleteDataSingleLine(client, line,data,char,length)
      sendMsg_cDeleteDataSingleLine(client, @name, line, data, char, length, @data[line])
    end

    def do_deleteDataSingleLine(client, jsonMsg)
      line = jsonMsg['deleteDataSingleLine']['line'].to_i
      data = jsonMsg['deleteDataSingleLine']['data'].to_s
      char = jsonMsg['deleteDataSingleLine']['ch'].to_i
      length = data.length
      deleteDataSingleLine(client, line, data, char, length)
    end

    def procMsg_deleteDataMultiLine(client, jsonMsg)
      ml = jsonMsg['deleteDataMultiLine']
      do_deleteDataMultiLine(client, jsonMsg)
      sendMsg_cDeleteDataMultiLine(client, @name, ml)
    end

    def do_deleteDataMultiLine(client, jsonMsg)
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
    end

    def sendMsg_cDeleteDataMultiLine(client, document, ml)
      ml['document'] = document;
      ml['sourceUser'] = client.name;
      puts $Project.dump(ml)
      clientReply = {
        'commandSet' => 'document',
        'command' => 'deleteDataMultiLine',
        'targetDocument' => name,
        'deleteDataMultiLine' => ml,
        #Temporary, each command should come in with a hash so we can deal with fails like this and rectify them
      }
      puts $Project.dump(clientReply)
      clientString = clientReply.to_json
      puts $Project.dump(clientString)
      @project.sendToClientsListeningExceptWS(client.websocket, document, clientString)

    end

    def deleteDataSingleLine(client, line,data,char,length)
      puts "deleteDataSingleLine(): Called  .. deleting " + data.inspect
      if (@data[line].nil?)
        puts "Error: Delete character on line that doesn't exist"
        #client.sendMsg_Fail('deleteDataSingleLine');
        return FALSE
      end
      if (data === "\n")
        # puts $Project.dump(@data)
        # -- @data.fetch(line, @data.fetch(line).slice!(char))
        if (@data.length > (line + 1))
          oldLine = @data.fetch(line) + @data.fetch(line+1)
          @data.delete_at(line)
          @data.insert(line, oldLine)
          # -- @data.(line, @data.fetch(line) + @data.fetch(line + 1))
          puts "Deleting line at " + (line + 1).to_s
          @data.delete_at(line + 1)
        end
        # puts $Project.dump(@data)
        return true
      end
      @str = @data.fetch(line).to_str
      @substr = @str[char..(char + length - 1)]
      # puts "Substr calculated to be " + @substr.inspect

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
        # puts "OK! " + @substr + " should match " +  data
        # puts "New string is " + @str
        puts @data.fetch(line, @str)
        return true
      else
        puts "Deleted data #{data} did not match data at string position #{char} with length #{length}! Server reports data is #{@substr}"
        #client.sendMsg_Fail('deleteDataSingleLine');
        return false
      end
    end
  end
