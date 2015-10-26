class DirectoryEntry < ActiveRecord::Base
  # Some really cool ActiveRecord stuff!
  belongs_to :owner, :class_name => "DirectoryEntry", :foreign_type => "DirectoryEntry", :foreign_key => "id"
  belongs_to :createdBy, class_name: "User", primary_key: "createdBy_id", foreign_key: "id"
  has_many :children, class_name: "DirectoryEntry", foreign_key: "owner_id", foreign_type: "DirectoryEntry", :dependent => :destroy
  has_many :filechanges, class_name: "FileChange", foreign_key: "DirectoryEntry_id", :dependent => :destroy
  after_initialize :make_ivs

  def make_ivs
    @dirMutex = Mutex.new
    @crdirMutex = Mutex.new
    @createFileMutex = Mutex.new
  end

  def create
    if (params[:owner_id].is_a?(Fixnum))
      # If we were passed an id, find the FD by ID
      #params[:owner_id] = DirectoryEntry.find_by_id(params[:owner_id])
    end
    @directoryEntry = DirectoryEntry.new(params)
    @directoryEntry.save!
  end
end

class DirectoryEntryCommandProcessor < DirectoryEntry
  def recvMsg_insertDataMultiLine(client, jsonMsg)
    startLine = jsonMsg['insertDataMultiLine']['startLine'].to_i
    n_startLine = startLine
    data = jsonMsg['insertDataMultiLine']['data']
    startChar = jsonMsg['insertDataMultiLine']['startChar'].to_i
    length = data.length
    FileChange.create(:changeType => "insertDataMultiLine", :changeData => (jsonMsg.to_json), :startLine => startLine, :startChar => startChar, :DirectoryEntry_id => self.id, :revision => self.filechanges.count, :User_id => client.userId)
  end

  def recvMsg_insertDataSingleLine(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Entered function")
    $Project.logMsg(LOG_FPARAMS, "client: " + YAML.dump(client))
    $Project.logMsg(LOG_FPARAMS, "jsonMsg: " + YAML.dump(jsonMsg))
    line = jsonMsg['insertDataSingleLine']['line'];
    odata = jsonMsg['insertDataSingleLine']['data']
    data = odata.sub("\r", "")
    char = jsonMsg['insertDataSingleLine']['ch'].to_i
    if (!data.is_a?(String))
      $Project.logMsg(LOG_ERROR, "Data was not a string, it was: " + data.class.to_s)
      $Project.logMsg(LOG_ERROR | LOG_VERBOSE | LOG_DEBUG | LOG_DUMP, "Data dump: " + YAML.dump(data))
      return false
    end
    length = data.length
    FileChange.create(:changeType => "insertDataSingleLine", :changeData => (jsonMsg.to_json), :startLine => line, :startChar => char, :DirectoryEntry_id => self.id, :revision => self.filechanges.count, :User_id => client.userId)
  end

  def recvMsg_deleteDataSingleLine(client, jsonMsg)
    line = jsonMsg['deleteDataSingleLine']['line'].to_i
    data = jsonMsg['deleteDataSingleLine']['data'].to_s
    char = jsonMsg['deleteDataSingleLine']['ch'].to_i
    length = data.length
    FileChange.create(:changeType => "deleteDataSingleLine", :changeData => (jsonMsg.to_json), :startLine => line, :startChar => char, :DirectoryEntry_id => self.id, :revision => self.filechanges.count, :User_id => client.userId)
  end

  def recvMsg_deleteDataMultiLine(client, jsonMsg)
    ml = jsonMsg['deleteDataMultiLine']
    startChar = ml['startChar'].to_i
    startLine = ml['startLine'].to_i
    endChar = ml['endChar'].to_i
    endLine = ml['endLine'].to_i
    lineData = ml['data']
    FileChange.create(:changeType => "deleteDataMultiLine", :changeData => (jsonMsg.to_json), :startLine => startLine, :startChar => startChar, :DirectoryEntry_id => self.id, :revision => self.filechanges.count, :User_id => client.userId)
  end

  def getDocument()
    document = @Project.getDocument(self.curName)
    if (!document)
      @Project.addDocument(self.curName, self.dbEntry)
    end
    document = @Project.getDocument(self.curName)
    if (!document.dbEntry)
      document.dbEntry = self
    end
    return document
  end

  def getMD5Hash(data)
    if (data.is_a?(String))
      #Return the hex-ified digest, base64 would be better
      digest = OpenSSL::Digest::MD5.hexdigest(data)
      return digest
    end
    $Project.logMsg(LOG_ERROR, "Data passed to me was not a string, try using .to_s, .inspect, .to_json, or YAML.dump() to get a hash")
    return false
  end

  def getPrivateDocument()
    $Project.logMsg(LOG_FENTRY, "Entered function")
    time = Time.new
    docName = getMD5Hash(self.curName + time.usec.to_s + Time.now.to_s)
    $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "Instantiating new Document with docName: #{docName} based off of MD5-Hash #{self.curName} with a nonce")
    document = Document.new(nil, docName, '/', self)
    $Project.logMsg(LOG_FENTRY, "Leaving function, TRUE, returning instantiated document")
    return document
  end


  def calcCurrent()
    $Project.logMsg(LOG_FENTRY, "Entered function, operating on #{self.curName} #{self.id}")
    $Project.logMsg(LOG_DEBUG | LOG_VERBOSE | LOG_DUMP, "Information about myself: " + YAML.dump(self))
    #This function takes us from revision 0 to current, we have no "key frames", but those will be added in the future to reduce processing time
    document = getPrivateDocument()
    $Project.logMsg(LOG_DEBUG, "Got a private document, processing self.filechanges.each")
    self.filechanges.each do |change|
      $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "Processing respond_to?s for a change: " + change.changeType)
      $Project.logMsg(LOG_DEBUG | LOG_VERBOSE | LOG_DUMP, YAML.dump(change))
      if (self.respond_to?("cmd_" + change.changeType))
        $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "self.cmd_ exists for this change, calling it -- we will NOT call document.do_ directly in this case")
        self.send("cmd_" + change.changeType, document, change)
        execCmd = true
      else
        $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "self.cmd_ does not exist, checking self.pre_ and document.do_")
        if (self.respond_to?("pre_" + change.changeType))
          execCmd = true
          $Project.logMsg(LOG_DEBUG | LOG_VERYVERBOSE, "self.pre_ exists for this change, calling it")
          self.send("pre_" + change.changeType, document, change)
        end
        if (document.respond_to?("do_" + change.changeType))
          execCmd = true
          $Project.logMsg(LOG_DEBUG | LOG_VERYVERBOSE, "document.do__ exists for this change, calling it")
          if (change.changeData.is_json?)
            document.send("do_" + change.changeType, nil, JSON.parse(change.changeData, :quirks_mode => true))
          else
            document.send("do_" + change.changeType, nil, change.changeData)
          end
        end
      end
      $Project.logMsg(LOG_DEBUG | LOG_INFO, "Document length is: " + document.getContents().length.to_s + " and number of lines is: " + document.getContents().split("\n").length.to_s)
    end
    $Project.logMsg(LOG_DEBUG, "Done processing changes")
    $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "Calling document.getContents() so we can return the data")
    contents = document.getContents()
    document = nil
    $Project.logMsg(LOG_FRETURN, "Returning with a " + contents.length.to_s + " byte document with " + contents.split("\n").length.to_s + " lines")
    $Project.logMsg(LOG_FRPARAM, contents)
    return({:data => contents})
  end

  def cmd_setContents(document, change)
    $Project.logMsg(LOG_FENTRY, "Entering function")
    $Project.logMsg(LOG_FPARAMS, "Document: " + YAML.dump(document))
    $Project.logMsg(LOG_FPARAMS, "Change: " + YAML.dump(change))
    if (!change.changeData.is_a?(String))
      $Project.logMsg(LOG_ERROR, "Passed incorrectly formatted changeData -- should be a string but it isn't")
      $Project.logMsg(LOG_ERROR | LOG_DEBUG | LOG_VERBOSE | LOG_DUMP, YAML.dump(change))
      $Project.logMsg(LOG_ERROR | LOG_DEBUG | LOG_VERBOSE | LOG_DUMP, change.inspect.to_s)
      document.setContents('SEVERE ERROR!! PASSED INCORRECT CHANGEDATA!')
      return false
    end
    data = change.changeData
    if (false && data.is_json?)
      $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "Setting to JSON.parse(data): " + YAML.dump(JSON.parse(data)))
      document.setContents((JSON.parse(data).split("\n")))
    else
      $Project.logMsg(LOG_DEBUG | LOG_VERBOSE | LOG_DUMP, "Setting to raw data: " + YAML.dump(data))
      $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "Data is a " + data.class.to_s)
      $Project.logMsg(LOG_DEBUG | LOG_VERBOSE | LOG_DUMP, "Inspected data: " + data.inspect.to_s)
      #data = data[1..-2].split("\n")
      if (data.include?("\n"))
        data = data.split("\n")
      else
        data = [ data ]
      end
      document.setContents(data)
    end
    return true
  end

  def setOptions(projName, sProject)
    @ProjectName = projName
    @Project = sProject
  end

end


class DirectoryEntryHelper < DirectoryEntryCommandProcessor
  def getRootDirectory
    # There should really only be one directory with no owner -- the root
    # directory. We'll give the system its own userid.
    a = DirectoryEntry.find_by_srcpath('/')
    if (!a)
      DirectoryEntry.create(:curName => @ProjectName, :owner_id => nil, :createdBy => nil, :srcpath => '/')
    end
    a = DirectoryEntry.find_by_srcpath('/')
    return a
  end

  def getBaseName(fileName)
    fileName = getDirArray(fileName);
    return fileName.last
  end

  def create(params)
    if (params[:owner_id].is_a?(Fixnum))
      params[:owner_id] = DirectoryEntry.find_by_id(params[:owner_id])
    end
    params.each do |key, value|
      $Project.logMsg(LOG_INFO | LOG_DEBUG, "#{key} has class: " + value.class.to_s)
    end
    @directoryEntry = DirectoryEntry.new(params)
    @directoryEntry.save!
  end

  def getNewestEntry()
    $Project.logMsg(LOG_FENTRY, "Called")
    begin
      #res = DirectoryEntry.find(:first, :order => "updated_at DESC")
      res = DirectoryEntry.order("updated_at DESC").offset(0).first
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught exception #{e.type.inspect} with message of #{e.message.inspect}")
      return(false)
    end
    $Project.logMsg(LOG_FRETURN, "Leaving function")
    return(res.updated_at)
  end


  def getDirectory(fileName)
    $Project.logMsg(LOG_FENTRY, "Called")
    fileName = getDirArray(fileName);
    fileName = fileName.take(fileName.length - 1)
    fileName.map
    if (fileName.drop(1).length == 0)
      return(['/'])
    end
    $Project.logMsg(LOG_FRETURN, "Leaving function")
    return fileName
  end

  def getDirArray(dirName)
    $Project.logMsg(LOG_FENTRY, "Entered function")
    $Project.logMsg(LOG_FPARAMS, "Called with dirName: #{dirName}")
    rere = dirName.split(/(?<=[\/])/)
    #rere = dirName.split(/\//)
    #rere = rere[1..(rere.length - 1)].map {|s| s = s.gsub('/','')}
    rere.delete("");

    if (!rere || !rere.length)
      rere = ['/']
    end
    #rere.map {|s| puts s.inspect }
    $Project.logMsg(LOG_FRETURN, "Exiting function, returning array of directories")
    $Project.logMsg(LOG_FRPARAM, rere.inspect)
    return rere
  end

  def dirExists(dirList)
    $Project.logMsg(LOG_FENTRY, "Entered function")
    $Project.logMsg(LOG_FPARAMS, "dirList: " + dirList.inspect)
    $Project.logMsg(LOG_INFO, "Waiting for dirMutex..")
    @dirMutex.synchronize {
      deb = dirExistsBase(dirList)
      $Project.logMsg(LOG_FRETURN, "Exiting function with return value from dirExistsBase()")
      return(deb)
    }
  end


  def dirExistsBase(dirList)
    $Project.logMsg(LOG_FENTRY, "Entered function")
    if (dirList.length == 1 && dirList[0] == '/')
      # The root directory always exists! Theoretically.
      return {:lastDir => getRootDirectory() }
    end
    if (dirList.length == 0)
      # No length could happen with some older versions of FileTree, we'll
      # keep it just in case.
      $Project.logMsg(LOG_WARN, "dirList.length was 0")
      $Project.logMsg(LOG_FRETURN, "Returning root directory")
      return {:lastDir => getRootDirectory() }
    end
    existingDirectories = dirList;

    lastDir = dirList.drop(dirList.length - 1).map { |s| s.inspect }.join().gsub('"','').gsub('/','');
    srcPath = existingDirectories.join()
    if (srcPath[-1] == '/')
      srcPath = srcPath[0..(srcPath.length - 2)]
    end
    if (srcPath[0] != '/')
      srcPath = '/' + srcPath
    end

    if (exDir = DirectoryEntry.find_by_srcpath(srcPath))
      $Project.logMsg(LOG_INFO | LOG_VERBOSE, "Found #{srcPath} by srcPath in the database!")
      $Project.logMsg(LOG_FRETURN, "Exiting function, returning directory information");
      $Project.logMsg(LOG_FRPARAM, "Return value: " + YAML.dump({:lastDir => exDir}));
      return{:lastDir => exDir}
    end
    $Project.logMsg(LOG_INFO | LOG_VERBOSE, "Unable to find directory #{srcPath} in the database")
    $Project.logMsg(LOG_FRETURN, "Exiting function, returning false")
    $Project.logMsg(LOG_FRPARAM, false)
    return(false)
  end

  def fileExists(srcPath)
    $Project.logMsg(LOG_FENTRY, "Entered function")
    $Project.logMsg(LOG_FPARAMS, "srcPath: #{srcPath}")
    if (srcPath[0] != '/')
      srcPath = '/' + srcPath
    end
    if (srcPath[-1] == '/')
      srcPath = srcPath[0..(srcPath.length - 2)]
    end
    if (exDir = DirectoryEntry.find_by_srcpath(srcPath))
      if ($Project)
        $Project.logMsg(LOG_FRETURN, "Found file by srcPath #{srcPath} in database!")
      end
      return{:lastDir => exDir}
    end
    if ($Project)
      $Project.logMsg(LOG_FRETURN, "Found no file by the name of #{srcPath} in database")
    end
    return(false)
  end


  def createFile(fileName, userId=nil, data=nil, mkdirp = false)
    $Project.logMsg(LOG_FENTRY, "Called")
    fromProcMsg = false
    fromdbBuildTree = false
    if (/procMsg/.match(caller_locations(1,1)[0].label))
      $Project.logMsg(LOG_INFO, "Called createFile() from procMsg_*")
      fromProcMsg = true
    end

    if (fromProcMsg == true && DirectoryEntryHelper.find_by_srcpath(fileName))
      $Project.logMsg(LOG_WARN, "fromProcMsg was set to true when perhaps it should not have been")
      return
    end

    if (/dbbuildTree/.match(caller_locations(1,1)[0].label))
      fromdbBuildTree = true
      $Project.logMsg(LOG_INFO, "Called createFile() from dbBuildTree -- bypassing mutex")
      return(createFileBase(fileName, userId, data, mkdirp, fromProcMsg, fromdbBuildTree))
    end

    $Project.logMsg(LOG_INFO, "Waiting for mutex.")
    @createFileMutex.synchronize {
      $Project.logMsg(LOG_INFO, "Got mutex, running createFileBase() ")
      return(createFileBase(fileName, userId, data, mkdirp, fromProcMsg, fromdbBuildTree))
    }
    $Project.logMsg(LOG_INFO, "Released mutex")
  end

  def createFileBase(fileName, userId=nil, data=nil, mkdirp = false, fromProcMsg, fromdbBuildTree)
    $Project.logMsg(LOG_FENTRY, "Called")
    baseName = getBaseName(fileName)
    dirList = getDirectory(fileName)
    clientErrors = []
    begin
      x = DirectoryEntryHelper.find_by_srcpath(fileName)
      if (fromdbBuildTree)
        $Project.logMsg(LOG_INFO, "fromdbBuildTree is true, expecting there to be filechanges in most documents..")
        $Project.logMsg(LOG_INFO, "fileName: #{fileName}")
        $Project.logMsg(LOG_INFO, "Number of changes: " + x.filechanges.count.to_s)
        $Project.logMsg(LOG_DEBUG | LOG_DUMP, "DEH find_by_srcpath:\n", YAML.dump(x))
      end
      if (x)
        if (x.filechanges.count > 0)
          # The database takes priority over the filesystem, although we may change this once we have a diff system in (so filesystem modifications affect the database)
          $Project.logMsg(LOG_INFO, "Current filechanges.count: " + x.filechanges.count.to_s)
          rval = x.calcCurrent()
          $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "calcCurrent gave us:")
          $Project.logMsg(LOG_DEBUG | LOG_DUMP, YAML.dump(rval))

          $Project.logMsg(LOG_INFO, "Setting data to rval[:data] from calcCurrent()")
          data = rval[:data].encode("UTF-8", invalid: :replace, undef: :replace, replace: '')
          rval = nil
        end
        if (!@Project.getDocument(fileName))
          $Project.logMsg(LOG_INFO, "Attempt to get document by fileName: #{fileName} failed, adding document")
          doc = @Project.addDocument(fileName, x)
        end
        if (data && (data.is_a?(String) || data.is_a?(Array)))
          $Project.logMsg(LOG_INFO, "Calling getDocument/setContents");
          doc = @Project.getDocument(fileName)
          doc.setContents(data)
        end
        return true
      end
      if (!(a = dirExists(dirList)))
        if (!mkdirp)
          $Project.logMsg(LOG_INFO, "Directory does not exist " + dirList.join() + " ..")
          $Project.logMsg(LOG_INFO, "Could not create file #{fileName} under non-existing directory")
          if (fromProcMsg)
            clientErrors << "Directory does not exist " + dirList.join() + " .."
            clientErrors << "Could not create file #{fileName} under non-existing directory"
            replyWith = {
              'status' => false,
              'errorReasons' => clientErrors,
            }
            $Project.logMsg(LOG_FRETURN, "Exiting with errors")
            return(replyWith)
          else
            $Project.logMsg(LOG_FRETURN, "Exiting with errors")
            return false
          end
        else
          myDirList = dirList.join('')
          if (myDirList[0] != '/')
            myDirList = '/' + myDirList
          end
          $Project.logMsg(LOG_INFO, "Attempting to create directory " + myDirList)
          rval = mkDir(myDirList)
          a = dirExists(dirList)
          if (!rval || !a)
            $Project.logMsg(LOG_ERROR, "createFile() failed to create Directory!")
            if (fromProcMsg)
              clientErrors << "createFile() failed to create Directory: " + myDirList
              replyWith = {
                'status' => false,
                'errorReasons' => clientErrors,
              }
              return(replyWith)
            else
              return false
            end
          end
        end
      end
      x = DirectoryEntryHelper.find_by_srcpath(fileName)
      if (!x)
        $Project.logMsg(LOG_INFO, "Couldn't find file by srcpath: #{fileName} in DB -- creating entry")
        # The file is NOT in the DB yet, add it!
        lastDir = a[:lastDir]
        newEntry = {:curName => baseName, :owner_id => lastDir.id, :createdBy_id => User.find_by_id(userId), :ftype => 'file', :srcpath => fileName }
        DirectoryEntryHelper.create(newEntry)
        x = DirectoryEntryHelper.find_by_srcpath(fileName)
      else
        clientErrors << "File already exists"
      end
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught exception: ")
      $Project.logMsg(LOG_EXCEPTION | LOG_DEBUG | LOG_DUMP, YAML.dump(caller))
      $Project.logMsg(LOG_EXCEPTION | LOG_DUMP | LOG_DEBUG, YAML.dump(e))
      exit
      return
    end

    if (x)
      # The file already exists in the db-- this is normal if we did a filesystem scan
      # on a second server boot, etc
      $Project.logMsg(LOG_INFO | LOG_DEBUG, "We have recorded " + x.filechanges.count.to_s + " filechanges to #{fileName}")
      if (data)
        $Project.logMsg(LOG_INFO | LOG_DEBUG, "We were called with data, only setting data if filechanges.count == 0")
      end
      begin
        if ((x.filechanges.count == 0) && data)
          # This file had no data before, but has been seen.. it has 0 changes made to it, so we just load it from disk with "setContents" as our command
          # All of the changeTypes will directly correlate to existing C->S API calls
          $Project.logMsg(LOG_INFO | LOG_DEBUG, "Filechange.create setContents data since x.filechanges.count == 0")
          if (userId == nil)
            userId = 1
          end
          $Project.logMsg(LOG_INFO | LOG_DEBUG, "Calling FileChange.create");
          $Project.logMsg(LOG_DEBUG | LOG_DUMP, "JSON data:" + ((data.encode('UTF-8', invalid: :replace, undef: :replace, replace: ''))).to_s);
          FileChange.create(:changeType => "setContents", :changeData => ((data.encode('UTF-8', invalid: :replace, undef: :replace, replace: ''))), :startLine => 0, :startChar => 0, :DirectoryEntry_id => x.id, :revision => 0, :User_id => userId)
        elsif (x.filechanges.count > 0)
          # The database takes priority over the filesystem, although we may change this once we have a diff system in (so filesystem modifications affect the database)
          $Project.logMsg(LOG_INFO, "Current filechanges.count: " + x.filechanges.count.to_s)
          rval = x.calcCurrent()
          $Project.logMsg(LOG_DEBUG | LOG_VERBOSE, "calcCurrent gave us:")
          $Project.logMsg(LOG_DEBUG | LOG_DUMP, YAML.dump(rval))

          $Project.logMsg(LOG_INFO, "Setting data to rval[:data] from calcCurrent()")
          data = rval[:data].encode("UTF-8", invalid: :replace, undef: :replace, replace: '')
          rval = nil
        end

      rescue Exception => e
        $Project.logMsg(LOG_EXCEPTION, "Caught exception: ")
        $Project.logMsg(LOG_EXCEPTION | LOG_DUMP | LOG_DEBUG, YAML.dump(e))
        bt = caller_locations(10)
        $Project.logMsg(LOG_EXCEPTION | LOG_DUMP | LOG_BACKTRACE, "Backtrace:\n" + YAML.dump(bt))
        exit
        return
      end
    end

    begin

      if (!@Project.getDocument(fileName))
        $Project.logMsg(LOG_INFO, "Adding document #{fileName}")
        doc = @Project.addDocument(fileName, x)
      end

      if (data && (data.is_a?(String) || data.is_a?(Array)))
        $Project.logMsg(LOG_INFO, "Calling getDocument/setContents")
        doc = @Project.getDocument(fileName)
        doc.setContents(data)
      end

      if (fromProcMsg)
        $Project.logMsg(LOG_INFO, "clientErrors.length: " + clientErrors.length.to_s)
        if (clientErrors.length == 0)
          $Project.logMsg(LOG_INFO, "No errors to report to client, A-OK")
          replyWith = {
            'status' => true,
            'DEHEntry' => x,
            'errorReasons' => false,
          }
        else
          $Project.logMsg(LOG_INFO | LOG_ERROR, "Unable to complete request for client, errors detected")
          $Project.logMsg(LOG_ERROR | LOG_DEBUG | LOG_DUMP, "clientErrors:\n" + YAML.dump(clientErrors))
          replyWith = {
            'status' => false,
            'errorReasons' => clientErrors,
          }
        end
        return replyWith
      end

      return true
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught exception: ")
      $Project.logMsg(LOG_EXCEPTION | LOG_DEBUG | LOG_DUMP, YAML.dump(caller))
      $Project.logMsg(LOG_EXCEPTION | LOG_DUMP | LOG_DEBUG, YAML.dump(e))
      abort("Serious error")
      return
    end
  end


  def mkDir(dirName, userId=nil)
    $Project.logMsg(LOG_FENTRY, "Called")
    # mkDir works like `mkdir -p`, it loops through the directory list from loop to end
    # and checks to see if it exists at each step -- if it doesn't, it calls createDirectory()
    # for a directory at each level in the tree.
    rere = getDirArray(dirName)
    $Project.logMsg(LOG_DEBUG, "mkDir(#{dirName}) .. " + rere.inspect.to_s)
    i = rere.length - 1

    a = dirExists(rere)
    if (a && a['last'])
      $Project.logMsg(LOG_INFO, "Shortcutting, dirExists(rere) gave me a directoryEntry")
      return(a['last'])
    end

    while (i > 0)
      #			puts "In main loop, checking dirExists " + rere.take(rere.length - i).join() + " .. "
      while dirExists(rere.take(rere.length - i)) && i > 0
        #				puts "In while loop! Checking for " + (rere.take(rere.length - i)).join()
        i -= 1
      end
      #			puts "Calling createDirectory! " + rere.take(rere.length - i - 1).inspect.to_s + " : " + rere.take(rere.length - i).last.gsub('/','').inspect.to_s
      dirList = rere.take(rere.length - i - 1)
      # if (!rere.take(rere.length - i - 1))
      #   dirList = ['/']
      # end
      newdir = createDirectory(dirList, rere.take(rere.length - i).last.gsub('/',''), userId);
      i -= 1
    end
    #		puts " -- Done creating directories -- "
    # Return the last directory created (last in the chain, this makes things easier
    # if we code for the return value properly)
    return newdir
  end


  def createDirectory(dirList, dirName, userId=nil)
    @crdirMutex.synchronize {
      return(createDirectoryBase(dirList, dirName))
    }
  end

  def createDirectoryBase(dirList, dirName, userId=nil)
    $Project.logMsg(LOG_FENTRY, "Called")
    $Project.logMsg(LOG_FPARAMS, "dirList:\n" + YAML.dump(dirList))
    $Project.logMsg(LOG_FPARAMS, "dirName:\n" + YAML.dump(dirName))

    # All but the last directory must exist, as opposed to mkdir which will automagically create directories a la "mkdir -p"
    # Ie if you want /server/testing/logs, you'd need to create /server, then /server/testing, then /server/testing/logs when calling this function
    # To make it slightly easier it takes an array ["/", "server","testing"] as the first argument, these directories should exist (and we check for that)
    # And it takes the new subdirectory name as the second argument, with the userId of the person creating the directory as an optional 3rd argument
    # userId may stay nil -- it will show up as "system generated" in that case
    $Project.logMsg(LOG_INFO, "Called to create #{dirName} under #{dirList.inspect}")
    srcPath =  dirList.map {|s| s.inspect}.join().gsub('"','').gsub('/','')
    existingDirectories = dirList.take(dirList.length);
    fullDirectory = existingDirectories
    fullDirectory << dirName
    a = dirExists(fullDirectory)
    if (a != false)
      $Project.logMsg(LOG_WARN, "Possible error: This directory #{dirName} has already been created! #{fullDirectory.inspect}")
      $Project.logMsg(LOG_DEBUG | LOG_DUMP, YAML.dump(a[:lastDir]))
      # The directory has already been created/properly exists, return the directory model to the calling function}
      return a[:lastDir]
    else
      $Project.logMsg(LOG_INFO, "Directory does not exist -- #{dirName}, that's good, it means we can possibly create it (if the preceding directories exist).")
      # We used to have a message here. Once we do some good logging functions we'll put it back in, no more puts
    end

    a = dirExists(dirList)
    if (a != false)
      # All but the last directory exist in the correct pathing
      $Project.logMsg(LOG_INFO, "dirExists(dirList) was true")
      lastDir = a[:lastDir]
      newEntry = {:curName => dirName, :owner_id => lastDir.id, :createdBy => User.find_by_id(userId), :ftype => 'folder', :srcpath => dirList.map {|s| s.inspect}.join().gsub('"','') + dirName}
      newDir = DirectoryEntryHelper.create(newEntry)
    else
      $Project.logMsg(LOG_INFO, "Some number of directories in dirList did not exist, so we couldn't create the directory")
      # Some of the directories in dirList did not exist so we could not create the newest directory
      return false
    end
    $Project.logMsg(LOG_INFO, "createDirectory(): Successfully created #{dirName} -- " + dirList.map {|s| s.inspect}.join().gsub('"','') + dirName)
    #puts YAML.dump(newDir)
    # We successfully created the directory, return the directory model
    return newDir
  end

  def rename(newName, newSrcPath = false)
    if (!newSrcPath)
      newSrcPath = getDirectory(self.srcpath).join().to_s + newName
    end
    if (self.ftype == 'directory')
      return(false)
    end
    self.curName = newName;
    self.srcpath = newSrcPath;
    self.save!
    if (self.ftype == 'directory')
      # We need some logic to re-write all the 'srcPaths'
      rewriteSrcPathForChildren()
    end
    return(true)
  end

end

class FileTreeX < DirectoryEntryHelper
  def initialize
    super
    @newestEntry = false
    @cachedJSONTree = false
  end

  def incRevision()
  end

  def jsonTree(start = nil, parent = false, tprepend='', tappend='')
    $Project.logMsg(LOG_FENTRY, "Called")
    begin
      if (start == nil)
        if (@newestEntry && @newestEntry == getNewestEntry() && @cachedJSONTree && @cachedJSONTree.length)
          $Project.logMsg(LOG_INFO, "Returning cached entry")
          return(@cachedJSONTree)
        end
        $Project.logMsg(LOG_INFO, "start = getRootDirectory()")
        start = getRootDirectory()
        if (start == nil)
          $Project.logMsg(LOG_ERROR, "FileTreeX getRootDirectory() failed")
          return
        end
        $Project.logMsg(LOG_INFO, "@newestEntry does not match getNewestEntry(), setting @newestEntry")
        @newestEntry = getNewestEntry()
        @cachedJSONTree = nil
        $Project.logMsg(LOG_INFO, "This ends the new code..")
      end

      $Project.logMsg(LOG_INFO, "This is after the start == nil block, we found the root directory..")
      $Project.logMsg(LOG_DEBUG | LOG_DUMP, "start:\n" + YAML.dump(start))
      jsonString = []
      if (start == getRootDirectory())
        type = 'root'
        ec = 'jsTreeRoot'
        icon = "jstree-folder"
        parent = "#"
        newId = sanitizeName(type, start.srcpath, tprepend, tappend)
        myJSON = [
          'id' => newId,
          'parent' => parent,
          'text' => start.curName,
          'type' => type,
          'li_attr' => {
            "class" => ec,
            #We need to Keep track of the srcPath.. perhaps in the DB
            'srcPath' => start.srcpath,
          },
        ]
        jsonString << myJSON
      end
      if (parent == "#")
        parent = "ft" + tprepend + "root0" + tappend
      end

      if (start != nil)
        start.children.each do |item|
          if (item.ftype == 'folder')
            type = 'folder'
            ec = 'jsTreeFolder'
            data = 'js'
            icon = 'jstree-folder'
          elsif (item.ftype == 'file')
            type = 'file'
            ec = 'jsTreeFile'
            icon = "jstree-file"
          else
            puts "Unknown type"
            type = 'file'
            ec = 'jsTreeFile'
            icon = "jstree-file"
          end
          newId = sanitizeName(type, item.srcpath, tprepend, tappend)
          myJSON = [
            'id' => newId,
            'parent' => parent,
            'text' => item.curName,
            'type' => type,
            'li_attr' => {
              "class" => ec,
              #We need to Keep track of the srcPath.. perhaps in the DB
              "srcPath" => item.srcpath,
            },
          ]
          jsonString << myJSON
          if (item.children.count > 0)
            jsonString << jsonTree(item, newId, tprepend, tappend)
          end
        end
      end
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught exception #{e.type.inspect} with message of #{e.message.inspect}")
      $Project.logMsg(LOG_EXCEPTION | LOG_DEBUG | LOG_DUMP, YAML.dump(e))
      return(false)
    end

    begin
      if (/root/.match(parent))
        #We really only need ftroot0 here, as I found out through experimentation
        #Give me a break, I've been up for over 20 hours!
        $Project.logMsg(LOG_INFO, "Matched root as parent, return flatten.to_json and set cachedJSONTree")
        @cachedJSONTree = jsonString.flatten.to_json
        $Project.logMsg(LOG_INFO, "Saved cachedJSONTree, returning it")
        return(@cachedJSONTree)
      end
      $Project.logMsg(LOG_INFO, "Not root, returning without flattening..")
      return(jsonString)
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught exception #{e.type.inspect} with message of #{e.message.inspect}")
      $Project.logMsg(LOG_EXCEPTION | LOG_DEBUG | LOG_DUMP, YAML.dump(e))
      return(false)
    end
  end

  def sanitizeName(type, name, tprepend='', tappend='')
    $Project.logMsg(LOG_FENTRY, "Called")
    begin
      if (type == 'root')
        return("ftroot0")
      end
      digest = OpenSSL::Digest::SHA256.hexdigest(name)
      # digest = digest[0..7] + digest[-8..-1]

      name = name + digest

      return("ft" + tprepend + type + "--" + digest + "--" + tappend)
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught exception #{e.type.inspect} with message of #{e.message.inspect}")
      $Project.logMsg(LOG_EXCEPTION | LOG_DEBUG | LOG_DUMP, YAML.dump(e))
      return(false)
    end
  end

  def procMsg(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called")
    $Project.logMsg(LOG_INFO, "Asked to process a message for myself: from client #{client.name}")
    if (self.respond_to?("procMsg_#{jsonMsg['command']}"))
      $Project.logMsg(LOG_INFO, "Found a function handler for  #{jsonMsg['command']}")
      self.send("procMsg_#{jsonMsg['command']}", client, jsonMsg);
    elsif
      $Project.logMsg(LOG_ERROR, "There is no function to handle the incoming command #{jsonMsg['command']}")
    end
  end

  def procMsg_getFileTreeJSON(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called")
    # This is currently the only client message we process, we will have to write
    # Move, delete, rename, etc. as well HERE and their supporting functions.
    clientReply = {
      'commandSet' => 'FileTree',
      'command' => 'setFileTreeJSON',
      'setFileTreeJSON' => {
        'fileTree' => jsonTree(),
      }
    }
    @Project.sendToClient(client, clientReply.to_json)
  end

  def procMsg_getFileTreeModalJSON(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called")
    #puts YAML.dump(jsonTree(nil, false, '', 'modal'))
    clientReply = {
      'commandSet' => 'FileTree',
      'command' => 'setFileTreeModalJSON',
      'setFileTreeModalJSON' => {
        'fileTree' => jsonTree(nil, false, '', 'modal'),
      }
    }
    @Project.sendToClient(client, clientReply.to_json)
    $Project.logMsg(LOG_FRETURN, "Exit")
  end

  def procMsg_createFile(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called")
    tData = jsonMsg['createFile']
    srcPath = tData['srcPath']
    hash = jsonMsg['hash']
    #def createFile(fileName, userId=nil, data=nil, mkdirp = false)
    #Temporarily attribute all changes to user 1, we should use client.id when
    #A&A is implemented
    if (srcPath[-1] == '/')
      # Account for trailing slashes, including the root directory _and remove them_
      if (srcPath.length > 1)
        srcPath = srcPath[0..-2]
      else
        srcPath = ''
      end
    end
    if (srcPath == '/')
      # Otherwise we append an extra / to account for directories not ending in /
      srcPath = ''
    end
    begin
      ctr = 0
      until (!fileExists(srcPath + "/Untitled" + ctr.to_s))
        ctr = ctr + 1
      end

      newFileName = "Untitled" + ctr.to_s

      nFile = createFile(srcPath + "/Untitled" + ctr.to_s, 1, '', false)
      if (srcPath == '/' || srcPath == "")
        ownerName = "ftroot0"
      else
        ownerName = sanitizeName('folder', srcPath)
      end
      if (nFile['status'] == false)
        clientReply = {
          'commandSet' => 'FileTree',
          'command' => 'createFile',
          'hash' => hash,
          'createFile' => {
            'status' => nFile['status'],
            'errorReasons' => nFile['errorReasons'],
          }
        }
        @Project.sendToClient(client, clientReply.to_json)
        return
      end

      fileTreeNode = {
        'id' => sanitizeName('file', nFile['DEHEntry'].srcpath),
        'parent' => ownerName,
        'text' => nFile['DEHEntry'].curName,
        'type' => 'file',
        'li_attr' => {
          "class" => 'jsTreeFile',
          "srcPath" => nFile['DEHEntry'].srcpath,
        },
      }
      clientReply = {
        'commandSet' => 'FileTree',
        'command' => 'createFile',
        'hash' => hash,
        'createFile' => {
          'status' => nFile['status'],
          'errorReasons' => nFile['errorReasons'],
          'srcPath' => nFile['DEHEntry'].srcpath,
          'node' => fileTreeNode,
        }
      }
      @Project.sendToClient(client, clientReply.to_json)
      broadcastReply = {
        'commandSet' => 'FileTree',
        'command' => 'createFile',
        'createFile' => {
          'createdBy' => client.name,   # client.id
          'srcPath' => nFile['DEHEntry'].srcpath,
        }
      }
      @Project.sendToClientsExcept(client, broadcastReply.to_json)
      $Project.logMsg(LOG_FRETURN, "Exiting!")
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught exception #{e.type.inspect} with message of #{e.message.inspect}")
      return(false)
    end
  end

  def procMsg_createDirectory(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called")
    tData = jsonMsg['createDirectory']
    srcPath = tData['srcPath']
    hash = jsonMsg['hash']
    #def createFile(fileName, userId=nil, data=nil, mkdirp = false)
    #Temporarily attribute all changes to user 1, we should use client.id when
    #A&A is implemented
    if (srcPath[-1] == '/')
      # Account for trailing slashes, including the root directory _and remove them_
      if (srcPath.length > 1)
        srcPath = srcPath[0..-2]
      else
        srcPath = ''
      end
    end
    if (srcPath == '/')
      # Otherwise we append an extra / to account for directories not ending in /
      srcPath = ''
    end
    begin
      ctr = 0
      until (!fileExists(srcPath + "/Untitled" + ctr.to_s))
        ctr = ctr + 1
      end

      newFileName = "Untitled" + ctr.to_s
      nFile = mkDir(srcPath + "/Untitled" + ctr.to_s, 1)

      if (srcPath == '/' || srcPath == "")
        ownerName = "ftroot0"
      else
        ownerName = sanitizeName('folder', srcPath)
      end

      # if (nFile['status'] == false)
      #   clientReply = {
      #     'commandSet' => 'FileTree',
      #     'command' => 'createFile',
      #     'hash' => hash,
      #     'createFile' => {
      #       'status' => nFile['status'],
      #       'errorReasons' => nFile['errorReasons'],
      #     }
      #   }
      #   @Project.sendToClient(client, clientReply.to_json)
      #   return
      # end
      if (!nFile)
        clientReply = {
          'commandSet' => 'FileTree',
          'command' => 'createDirectory',
          'hash' => hash,
          'createDirectory' => {
            'status' => false,
            'errorReasons' => ['NYI',"We haven't added error reasons to mkDir depending on calling function type yet.. mkDir() should never fail, though -- check the server logs"]
          }
        }
        @Project.sendToClient(client, clientReply.to_json)
        return(false);
      end
      fileTreeNode = {
        'id' => sanitizeName('folder', nFile.srcpath),
        'parent' => ownerName,
        'text' => nFile.curName,
        'type' => 'folder',
        'li_attr' => {
          "class" => 'jsTreeFolder',
          "srcPath" => nFile.srcpath,
        },
      }
      clientReply = {
        'commandSet' => 'FileTree',
        'command' => 'createDirectory',
        'hash' => hash,
        'createDirectory' => {
          'status' => true,
          'errorReasons' => false,
          'srcPath' => nFile.srcpath,
          'node' => fileTreeNode,
        }
      }
      @Project.sendToClient(client, clientReply.to_json)
      broadcastReply = {
        'commandSet' => 'FileTree',
        'command' => 'createDirectory',
        'createDirectory' => {
          'createdBy' => client.name,   # client.id
          'srcPath' => nFile.srcpath,
        }
      }
      @Project.sendToClientsExcept(client, broadcastReply.to_json)
      $Project.logMsg(LOG_FRETURN, "Returning")
    rescue Exception => e

      $Project.logMsg(LOG_EXCEPTION, "Caught exception #{e.type.inspect} with message of #{e.message.inspect}")
      return(false)
    end
    return(true)
  end



  def procMsg_renameEntry(client, jsonMsg)
    $Project.logMsg(LOG_FENTRY, "Called")
    begin
      tData = jsonMsg['renameEntry']
      srcPath = tData['srcPath']
      newName = tData['newName']
      hash = tData['hash']
      if (tData['srcPath'] == '/')
        clientReply = {
          'commandSet' => 'FileTree',
          'command' => 'renameEntry',
          'hash' => hash,
          'renameEntry' => {
            'status' => false,
            'errorReasons' => ["NYI","You can't rename the root directory at this time (not even the nice name.. ie NYI)"],
          }
        }
        @Project.sendToClient(client, clientReply.to_json)
        return(false)
      end

      fEntry = DirectoryEntryHelper.find_by_srcpath(srcPath)
      if (!fEntry)
        $Project.logMsg(LOG_ERROR, "Unable to find file/directory entry by srcPath #{srcPath}")
        $Project.logMsg(LOG_FRETURN, "Leaving, returning false")
        return(false)
      end

      if (fEntry.ftype == 'folder')
        clientReply = {
          'commandSet' => 'FileTree',
          'command' => 'renameEntry',
          'hash' => hash,
          'renameEntry' => {
            'status' => false,
            'errorReasons' => ["NYI",'Renaming directories is not yet implemented'],
          }
        }
        @Project.sendToClient(client, clientReply.to_json)
        return(false)
      end
      $Project.logMsg(LOG_INFO, "Calling DirectoryEntryHelper instantiation fEntry.rename() with #{newName}")
      rval = fEntry.rename(newName)
      if (!rval)
        clientReply = {
          'commandSet' => 'FileTree',
          'command' => 'renameEntry',
          'hash' => hash,
          'renameEntry' => {
            'status' => false,
            'errorReasons' => ['Failed rename() call'],
          }
        }
        @Project.sendToClient(client, clientReply.to_json)
        return(false)
      end

      if (srcPath == '/' || srcPath == "")
        ownerName = "ftroot0"
      else
        ownerName = sanitizeName('folder', fEntry.owner.srcpath)
      end

      fileTreeNode = {
        'id' => sanitizeName('file', fEntry.srcpath),
        'parent' => ownerName,
        'text' => fEntry.curName,
        'type' => 'file',
        'li_attr' => {
          "class" => 'jsTreeFile',
          "srcPath" => fEntry.srcpath,
        },
      }
      clientReply = {
        'commandSet' => 'FileTree',
        'command' => 'renameEntry',
        'hash' => hash,
        'renameEntry' => {
          'status' => true,
          'errorReasons' => false,
          'srcPath' => fEntry.srcpath,
          'deleteFileTreeObject' => sanitizeName(fEntry.ftype, srcPath),
          'replacementFileTreeObject' => fileTreeNode,
        }
      }
      @Project.sendToClient(client, clientReply.to_json)
    rescue Exception, TypeError, NameError => e
      STDERR.puts "Rescued from error: #{e}"
    end
  end

  def procMsg_deleteEntry(client, jsonMsg)
    STDERR.puts YAML.dump(jsonMsg)
    tData = jsonMsg['deleteEntry']
    srcPath = tData['srcPath']
    # if (!/^\//.match(srcPath))
    #   srcPath = /\/.*/.match(srcPath)[0]
    # end
    fEntry = DirectoryEntry.find_by_srcpath(srcPath)
    if (!fEntry)
      $Project.logMsg(LOG_ERROR, "Unable to find by srcPath "  + srcPath)
    end
    DirectoryEntry.destroy(fEntry.id)
  end
end
