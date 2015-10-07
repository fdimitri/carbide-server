require 'json'
require 'yaml'

# This is a file system scanner that makes calls to the psuedo-file system in
# the database, it may be called at any time to import new files.

class FileSystemBase

  def initialize(baseDirectory, fileTree)
    @fileTree = fileTree
    @baseDirectory = baseDirectory
fileBeginings = "([RM]akefile|Gemfile|README|LICENSE|config|MANIFEST|COMMIT_EDITMSG|HEAD|index|desc)"
fileEndings = "(erb|rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess|c|rd|cpp)"	
	@FileEndings = "\.#{fileEndings}$"
	@FileBeginings = "^#{fileBeginings}"

  end

  def getFilesFromDirectory(directoryName)
    files = Dir.entries(directoryName).select { |f| !File.directory? f }
    return files
  end

  def getDirectoriesFromDirectory(directoryName)
    #puts "getDirectoriesFromDirectory(#{directoryName})"
    dirs = Dir.entries(directoryName).select { |f| ((File.directory? f) && f != '.' && f != '..')}
    puts YAML.dump(dirs)
    return dirs
  end


  def buildTree(path=@baseDirectory, name=nil)
    data = {'name' => (name || path)}
    data['children'] = children = []
    if (path == @baseDirectory)
      data['type'] = 'root'
    end
    Dir.foreach(path) do |entry|
      next if (entry == '..' || entry == '.' )
      full_path = File.join(path, entry)
      if File.directory?(full_path)
        newEntry = buildTree(full_path, entry)
        newEntry['type'] = File.ftype(full_path)
        newEntry['fullPath'] = stripPath(full_path)
        children << newEntry
      else
        newEntry = {'name' => entry, 'type' => File.ftype(full_path), 'fullPath' => stripPath(full_path) }
        children << newEntry
      end
    end
    return data
  end

  def stripPath(path)
    newPath = path.gsub(@baseDirectory, "")
    return newPath
  end

  def createFileTree(tree)
    # puts YAML.dump(tree)
    if (!tree['children'])
      #puts tree
      # This should never happen.. deprecate this entire if block, we never call
      # createFileTree(value) when value['type'] == file, although files will
      # not have children they will not see this function as the tree parameter
      if (tree['type'] == 'file')
        if (/#{@FileEndings}/.match(tree['name']) || /#{@FileBeginings}/.match(tree['name']))
          #puts "Attempting to open file: " + @baseDirectory + tree['fullpath']
          fd = File.open(@baseDirectory + tree['fullpath'], "rb");
          data = fd.read.force_encoding('utf-8')
          fd.close
          @fileTree.createFile(tree['name'], nil, data)
          puts "createFile #{tree['name']}"
        else
          x = DirectoryEntryHelper.find_by_srcpath(value['fullPath'])
          if (x)
            YAML.dump(x.filechanges)
            YAML.dump(x.filechanges.count)
          else
            YAML.dump(x)
          end
          @fileTree.createFile(tree['name'])
        end

      elsif (tree['type'] == 'directory')
        # This is possible.. but we don't need to createFileTree(value) since we
        # have no children.. removed, case: Directory with no files or directories.
        @fileTree.mkDir(tree['name'])
        #puts "createFileTree(): mkDir(1) #{tree['name']}"
        #createFileTree(value)
      end
      return
    end



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
          if (x.filechanges.count > 0)
            @fileTree.createFile(value['fullPath'], nil, nil)
            next
          end
        else
          # File doesn't exist
        end
        if (/#{@FileEndings}/.match(value['name']) || /#{@FileBeginings}/.match(value['name']))
          # If it's a file that matches out hacked in regex, let's read it and pass the data along to createFile()
          if (!x || (x && x.filechanges.count == 0))
            #puts "Attempting to open file: " + @baseDirectory + value['fullPath']
            fd = File.open(@baseDirectory + value['fullPath'], "rb");
if (fd == false) 
while (!fd) do
fd = File.open(@baseDirectory + value['fullPath'], "rb");
end
end
            data = fd.read
            fd.close
            @fileTree.createFile(value['fullPath'], nil, data)
            puts "createFile #{value['fullPath']} with data"
          else
            @fileTree.createFile(value['fullPath'], nil, nil)
          end

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
