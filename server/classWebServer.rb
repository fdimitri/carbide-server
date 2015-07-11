require 'webrick'
require 'yaml'

class UploadBase < WEBrick::HTTPServlet::AbstractServlet
  def getParams(request)
    rq = request.query()
    params = Hash.new;
    rq.each do |key,val|
      params[key] = val.to_s
    end
    if (params['srcPath'].length == 1 && params['srcPath'][0] == '/')
      params['srcPath'] = ''
    end
    if (params['srcPath'] && params['srcPath'].length > 1 && params['srcPath'][0] == '/')
      params['srcPath'] = params['srcPath'][1..-1]
    end
    if (params['srcPath'] && params['srcPath'].length > 1 && !params['srcPath'][-1] == '/')
      params['srcPath']  = params['srcPath'] + '/'
    end
    return params
  end

  def do_GET(request, response)
    response['Access-Control-Allow-Origin'] = "*"
    response['Accept-Encoding'] = "gzip"
    params = getParams(request);
    #params = request['request_uri']
    #chunk folder path based on the parameters

    dir = File.expand_path("#{@tempDir}/#{params['srcPath']}")
    #chunk path based on the parameters
    if (params.has_key?('flowRelativePath'))
      file = "#{dir}/#{params['flowRelativePath']}" + ".part#{params["flowChunkNumber"]}"
    else
      file = "#{dir}/#{params["flowFilename"]}" + ".part#{params["flowChunkNumber"]}"
    end

    if File.exists?(file)
      #Let flow.js know this chunk already exists
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = "Exists!"
    else
      #Let flow.js know this chunk doesnt exists and needs to be uploaded
      response.status = 404
      response['Content-Type'] = 'text/plain'
      response.body = "Doesn't exist!"
    end
  end

  def do_POST(request, response)
    response['Access-Control-Allow-Origin'] = "*"
    response['Accept-Encoding'] = "gzip"
    params = getParams(request)
    #chunk folder path based on the parameters
    dir = File.expand_path("#{@tempDir}/#{params['srcPath']}")
    srcPath = params['srcPath']
    #chunk path based on the parameters
    if (params.has_key?('flowRelativePath'))
      file = "#{dir}/#{params['flowRelativePath']}"
    else
      file = "#{dir}/#{params["flowFilename"]}"
    end
    chunk = file + ".part#{params["flowChunkNumber"]}"
    # Create chunks directory when not present on system
    dirname = File.dirname(file)
    if (dirname)
      if !File.directory?(dirname)
        puts "Attempt to create directory: #{dirname}"
        FileUtils.mkdir_p(dirname, :mode => 0777)
      end
    end
    # Write the chunk out to a file
    if (params['file'].length == params["flowCurrentChunkSize"].to_i)
      writeFile(srcPath, chunk, params["file"])
      params["file"] = nil
    else
      puts "UploadBase::do_POST(): Severe error, chunk.length != flowCurrentChunkSize: " + chunk.length.to_s + " != " + params["flowCurrentChunkSize"].to_s
      response.status = 500
      response['Content-Type'] = 'text/plain'
      response.body = "Your chunk wasn't what you claimed it would be."
      response['Access-Control-Allow-Origin'] = "*"
      return(response)
    end

    currentSize = params["flowChunkNumber"].to_i * params["flowChunkSize"].to_i
    filesize = params["flowTotalSize"].to_i

    #When all chunks are uploaded
    #Concatenate all the partial files into the original file
    if (params.has_key?('flowRelativePath'))
      nfile = "#{@baseDirectory}/#{params['srcPath']}#{params['flowRelativePath']}"
    else
      nfile = "#{@baseDirectory}/#{params['srcPath']}#{params["flowFilename"]}"
    end

    if (currentSize + params["flowCurrentChunkSize"].to_i) >= filesize
      #Create a target file
      dirname = File.dirname(nfile)
      if (dirname)
        if !File.directory?(dirname)
          FileUtils.mkdir_p(dirname, :mode => 0777)
        end
      end
      fileTree = @WebServer.Project.FileTree;
      if (fileTree.fileExists(stripPath(nfile) || File.exists?(nfile)))
        response.status = 404
        response['Content-Type'] = 'text/plain'
        response.body = "File already exists: " + stripPath(nfile)
        response['Access-Control-Allow-Origin'] = "*"
        return(response)
      end

      targetFile = File.open("#{nfile}","a+b")
      if (!targetFile)
        response.status = 500
        response['Content-Type'] = 'text/plain'
        response.body = "Unable to create targetFile #{dir}/#{params['srcPath']}#{params["flowFilename"]}, but we still have all of the parts saved"
        response['Access-Control-Allow-Origin'] = "*"
        return
      end


      #Loop trough the chunks
      while (@t[srcPath].count > 0) do
        puts "Waiting for threads to finish writing.."
        @t[srcPath].each { |t| t.join unless (t.alive?) }
        @t[srcPath].delete_if { |t| !t.alive?}
        sleep 0.5
      end

      for i in 1..params["flowChunkNumber"].to_i
        #Select the chunk
        chunk = File.open("#{file}.part#{i}", 'rb')
        #Write chunk into target file
        targetFile.write(chunk.read)
        chunk.close()
        #Deleting chunk
        FileUtils.rm "#{file}.part#{i}", :force => true
      end
      puts "File saved to #{nfile}"
      targetFile.fsync()
      targetFile.close()
      localPath = stripPath(nfile)
      if ((/\.(rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess|c|rd|cpp)$/.match(nfile)) || (/^([RM]akefile|Gemfile|README|LICENSE|config|MANIFEST|COMMIT_EDITMSG|HEAD|index|desc)/.match(nfile)))
        fd = File.open(nfile, "rb");
        data = fd.read
        fd.close
        puts "@WebServer.Project.FileTree.createFile(#{localPath}, nil, data, true)"
        @WebServer.Project.FileTree.createFile(localPath, nil, data, true)
      else
        puts "@WebServer.Project.FileTree.createFile(#{localPath}, nil, nil, true)"
        @WebServer.Project.FileTree.createFile(localPath, nil, nil, true)
      end
    else
      puts "Saving chunk.."
    end

    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = "Successfully saved #{params["flowFilename"]}"
    response['Access-Control-Allow-Origin'] = "*"

  end

  def stripPath(path)
    newPath = path.gsub(@baseDirectory, "")
    return newPath
  end

  def writeFile(srcPath, fileName, data, opts='wb')
    @t = Hash.new unless (@t)
    @t[srcPath] = [] unless @t[srcPath]
    @t[srcPath] << Thread.new {
      fd = File.open(fileName, opts)
      fd.write(data)
      fd.fsync()
      fd.close()
    }
    @t[srcPath].each { |t| t.join unless (t.alive?) }
    @t[srcPath].delete_if { |t| !t.alive?}
  end


  def do_OPTIONS(request, response)
    puts "do_OPTIONS called"
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = "You got your options!"
    response['Access-Control-Allow-Origin'] = "*"
    m = self.methods.grep(/\Ado_([A-Z]+)\z/) {$1}
    m.sort!
    response["allow"] = m.join(",")
  end
end

class UploadFile < UploadBase
  def initialize(server, tempDir, dlDir, webServer)
    puts "Initialize UploadBase"
    super server
    @tempDir = tempDir
    @dlDir = tempDir
    @WebServer = webServer
    @baseDirectory = dlDir
    puts "Initialize UploadBase End"
  end


end


class WebServer
  attr_accessor :Project
  def initialize (port, root)
    @port = port
    @root = root
    access_log = [
      [$stdout, WEBrick::AccessLog::COMMON_LOG_FORMAT],
      [$stdout, WEBrick::AccessLog::REFERER_LOG_FORMAT],
      [$stdout, WEBrick::AccessLog::COMBINED_LOG_FORMAT],
    ]
    @root = File.expand_path(root)
    @server = WEBrick::HTTPServer.new(:Port => port, :DocumentRoot => @root, :BindAddress => "0.0.0.0", :AccessLog => access_log, :ServerName => "172.17.0.42:6400")
    trap 'INT' do
      puts "Received INT.. shutting down server"
      @server.shutdown
    end
    a = @server.mount '/upload', UploadFile, @root + "/uploads", @root, self
  end

  def registerProject(project)
    @Project = project
  end

  def start()
    res = @server.start
  end


end
