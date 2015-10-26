require 'json'
require 'yaml'

# This is a file system scanner that makes calls to the psuedo-file system in
# the database, it may be called at any time to import new files.

class DBFSBase

  def initialize(fileTree)
    @createThreadList = []
    @buildThreadList = []
    @fileTree = fileTree
    @baseDirectory = "/"
    fileBeginings = "([RM]akefile|Gemfile|README|LICENSE|config|MANIFEST|COMMIT_EDITMSG|HEAD|index|desc)"
    fileEndings = "[\.](erb|rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess|c|rd|cpp|sql)"
    @FileEndings = "#{fileEndings}$"
    @FileBeginings = "^#{fileBeginings}"
  end


  def dbbuildTree(path=@baseDirectory, name=nil)
    $Project.logMsg(LOG_FENTRY, "Called")
    $Project.logMsg(LOG_FENTRY, "path: " + path.to_s)
    if (name)
      $Project.logMsg(LOG_FENTRY, "name" + name.to_s)
    end

    data = {'name' => (name || path)}
    data['children'] = children = []

    if (path == @baseDirectory && !name)
      $Project.logMsg(LOG_INFO, "data['type'] set to 'root'")
      data['type'] = 'root'
    end
    if (name)
      if (name[0] == "/")
        name = name[1..-1]
      end
      srcPath = path + name
      if (!(path[-1] == '/'))
        srcPath = path + "/" + name
      end
      $Project.logMsg(LOG_INFO, "srcPath set to #{srcPath}")
    else
      srcPath = path
      $Project.logMsg(LOG_INFO, "srcPath set to #{srcPath}")
    end

    dirEntry = DirectoryEntry.find_by_srcpath(srcPath)
    if (!dirEntry)
      $Project.logMsg(LOG_ERROR, "Unable to find directory entry by srcPath #{srcPath} -- this should never happen in DBFS")
      abort("DBFS Failure")
      return(nil)
    end
    begin
      buildThreadList = []
      deChildren = dirEntry.children.find_by_ftype('folder')
      if (deChildren.is_a?(Array))
        deChildren.each do |entry|
          buildThreadList << Thread.new do
            Thread.current['children'] = []
            newEntry = dbbuildTree('/', entry.srcpath)
            newEntry['type'] = 'directory'
            newEntry['fullPath'] = entry.srcpath
            Thread.current['children'] << newEntry
          end
        end
      else
        entry = deChildren
        newEntry = dbbuildTree('/', entry.srcpath)
        newEntry['type'] = 'directory'
        newEntry['fullPath'] = entry.srcpath
        children << newEntry
      end
      deChildren = dirEntry.children.find_by_ftype('file')
      if (deChildren.is_a?(Array))
        deChildren.each do |entry|
          newEntry = {'name' => entry.curName, 'type' => 'file', 'fullPath' => entry.srcpath }
          children << newEntry
        end
      else
        entry = deChildren
        newEntry = {'name' => entry.curName, 'type' => 'file', 'fullPath' => entry.srcpath }
      end
      if (buildThreadList.length > 0)
        buildThreadList.each do |cthr|
          cthr.join
          cthr['children'].each do |child|
            children << child
          end
        end
      end
    rescue Exception => e
      $Project.logMsg(LOG_EXCEPTION, "Caught Exception!")
      $Project.logMsg(LOG_EXCEPTION | LOG_DUMP | LOG_DEBUG, "Exception:\n" + YAML.dump(e))

    end
    return data
  end

  def dbcreateFileTree(tree)
    tree['children'].each do |value, k|
      # Ignore files, let's do directories first! Yes, it means two loop iterations, there was a reason for this with the old code.. they could
      # probably be combined into a single loop now.
      next if (value['type'] == 'file')
      # We can't just skip a directory if it already exists like we can with files, we still have to deal with possible additions to the
      # directory's list of children (ie new files and/or subdirectories)
      if (value['type'] == 'directory')
        # If the directory exists, do not try to create it again -- but still call
        # createFileTree(value) as it may have children that we have not encountered before
        if (!@fileTree.fileExists(value['fullPath']))
          #puts "createFileTree(): mkDir(2) #{value['fullPath']}"
          @fileTree.mkDir(value['fullPath'])
        end
        dbcreateFileTree(value)
      elsif (value['type'] == 'root')
        #createFileTree(value)
        # This is impossible.. root cannot be a child of anything
      else
        puts "Unknown type #{value['type']}"
      end
    end

    tree['children'].each do |value, k|
      next if (value['type'] == 'directory')
      if (value['type'] == 'file')
        # If the file already exists in the database, DO NOTHING!
        x = DirectoryEntryHelper.find_by_srcpath(value['fullPath'])
        if (x)
          @createThreadList << Thread.new do
            $Project.logMsg(LOG_INFO, "Launched thread to createFile")
            @fileTree.createFile(value['fullPath'], nil, nil)
          end
        end
      else
        $Project.logMsg(LOG_ERROR, "This shouldn't ever happen, couldn't find by srcPath: #{value['fullPath']}")
        abort("MAJOR ISSUE")
      end
    end
  end
end
