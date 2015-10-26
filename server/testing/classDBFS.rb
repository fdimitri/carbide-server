require 'json'
require 'yaml'

# This is a file system scanner that makes calls to the psuedo-file system in
# the database, it may be called at any time to import new files.

class DBFSBase

  def initialize(fileTree)
    @fileTree = fileTree
    @baseDirectory = "/"
    fileBeginings = "([RM]akefile|Gemfile|README|LICENSE|config|MANIFEST|COMMIT_EDITMSG|HEAD|index|desc)"
    fileEndings = "[\.](erb|rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess|c|rd|cpp|sql)"
    @FileEndings = "#{fileEndings}$"
    @FileBeginings = "^#{fileBeginings}"
  end


  def buildTree(path=@baseDirectory, name=nil)
    $Project.logMsg(LOG_FENTRY, "Called")
    $Project.logMsg(LOG_FENTRY, "path: " + path.to_s)
    if (name)
      $Project.logMsg(LOG_FENTRY, "name" + name.to_s)
    end

    data = {'name' => (name || path)}
    data['children'] = children = []

    if (path == @baseDirectory)
      $Project.logMsg(LOG_INFO, "data['type'] set to 'root'")
      data['type'] = 'root'
    end
    if (name)
      srcPath = path + name
      if (!(path[-1] == '/'))
        srcPath = path + "/" + name
      end
      $Project.logMsg(LOG_INFO, "srcPath set to #{srcPath}")
    else
      srcPath = path
      $Project.logMsg(LOG_INFO, "srcPath set to #{srcPath}")
    end

    dirEntry =  DirectoryEntry.find_by_srcpath(srcPath)
    if (!dirEntry)
      $Project.logMsg(LOG_ERROR, "Unable to find directory entry by srcPath #{srcPath} -- this should never happen in DBFS")
      abort("DBFS Failure")
      return(nil)
    end

    dirEntry.children.each do |entry|
      if (entry.ftype == 'directory')
        newEntry = buildTree(entry.srcpath, entry.curName)
        newEntry['type'] = entry.ftype
        newEntry['fullPath'] = entry.srcPath
        children << newEntry
      else
        newEntry = {'name' => entry.curName, 'type' => entry.ftype, 'fullPath' => entry.srcpath }
        children << newEntry
      end
    end
    return data
  end

  def createFileTree(tree)
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
        createFileTree(value)
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
#          if (x.filechanges.count > 0)
            @fileTree.createFile(value['fullPath'], nil, nil)
            next
#          end
        else
          # File doesn't exist
        end
        if (/#{@FileEndings}/.match(value['name']) || /#{@FileBeginings}/.match(value['name']))
            @fileTree.createFile(value['fullPath'], nil, nil)
        else
          # If we don't like the name or file extension, we just create a file with no data entry.. we should really load all files, but we don't deal with binaries yet
          # The Document abstraction doesn't allow for that, we really need a File abstraction instead
          # In fact, we don't even properly deal with non ASCII-8 files, we need to do some encoding checks to see if they're UTF-8, or have a JPEG header, etc.
          # We may have to shell out to GNU's 'file' for that, or build a Gem wrapper for 'file' if such a thing does not exist
          @fileTree.createFile(value['fullPath'])
          #puts "createFile #{value['fullPath']} without data"
        end
      else
        # We shouldn't encounter this.
        puts "Unknown type #{value['type']}"
      end
    end
  end
end
