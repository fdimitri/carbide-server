require 'webrick'
require 'yaml'

class UploadBase < WEBrick::HTTPServlet::AbstractServlet
  def getParams(request)
    rq = request.query()
    params = Hash.new;
    rq.each do |key,val|
        #puts YAML.dump(val.to_s)
        params[key] = val.to_s
    end
    return params
  end

  def do_GET(request, response)
    response['Access-Control-Allow-Origin'] = "*"
    response['Accept-Encoding'] = "gzip"
    params = getParams(request);
    #params = request['request_uri']
    #chunk folder path based on the parameters
    dir = File.expand_path("#{@tempDir}/")
    #chunk path based on the parameters
    if (params.has_key?('flowRelativePath'))
      file = "#{dir}/#{params['flowRelativePath']}"
    else
      file = "#{dir}/#{params["flowFilename"]}"
    end
#    chunk = file + ".part#{params["flowChunkNumber"]}-#{params["flowIdentifier"]}"

    #dir = File.expand_path("#{@tempDir}/#{params["flowIdentifier"]}")
    #chunk path based on the parameters
    #chunk = "#{dir}/#{params["flowFilename"]}.part#{params["flowChunkNumber"]}"
    #puts "Checking existince of #{chunk}"
    #if File.exists?(chunk)
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
    dir = File.expand_path("#{@tempDir}/")
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
    chunkFile = File.open(chunk, "wb")
    chunkFile.write(params["file"])
    chunkFile.fsync()
    chunkFile.close()
    params["file"] = nil

    currentSize = params["flowChunkNumber"].to_i * params["flowChunkSize"].to_i
    filesize = params["flowTotalSize"].to_i

    #When all chunks are uploaded
    #Concatenate all the partial files into the original file
    if (params.has_key?('flowRelativePath'))
      nfile = "#{@baseDirectory}/#{params['flowRelativePath']}"
    else
      nfile = "#{@baseDirectory}/#{params["flowFilename"]}"
    end

    if (currentSize + params["flowCurrentChunkSize"].to_i) >= filesize
      #Create a target file
      dirname = File.dirname(nfile)
      if (dirname)
        if !File.directory?(dirname)
          FileUtils.mkdir_p(dirname, :mode => 0777)
        end
      end

      targetFile = File.open("#{nfile}","a+b")
      if (!targetFile)
        response.status = 500
        response['Content-Type'] = 'text/plain'
        response.body = "Unable to create targetFile #{dir}/#{params["flowFilename"]}"
        response['Access-Control-Allow-Origin'] = "*"
        return
      end

      #Loop trough the chunks
      for i in 1..params["flowChunkNumber"].to_i
        #Select the chunk
        chunk = File.open("#{file}.part#{i}", 'rb')
        #Write chunk into target file
        targetFile.write(chunk.read)
        chunk.close()
        #Deleting chunk
        FileUtils.rm "#{file}.part#{i}", :force => true
      end
      puts "File saved to #{dir}/#{params["flowFilename"]}"
      targetFile.fsync()
      targetFile.close()
      if ((/\.(rb|html|php|out|save|log|js|txt|css|scss|coffee|md|rdoc|htaccess|c|rd|cpp)$/.match(nfile)) || (/^([RM]akefile|Gemfile|README|LICENSE|config|MANIFEST|COMMIT_EDITMSG|HEAD|index|desc)/.match(nfile)))
        YAML.dump(nfile)
        fd = File.open(nfile, "rb");
        data = fd.read
        fd.close
        @WebServer.Project.FileTree.createFile('/' + stripPath(nfile), nil, data, true)

        puts "createFile(" + stripPath(nfile) + ")"
      else
        @WebServer.Project.FileTree.createFile('/' + stripPath(nfile), nil, nil, true)
        YAML.dump(nfile)
        puts "createFile(" + stripPath(nfile) + ")"
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
      [$stderr, WEBrick::AccessLog::COMMON_LOG_FORMAT],
      [$stderr, WEBrick::AccessLog::REFERER_LOG_FORMAT],
      [$stderr, WEBrick::AccessLog::COMBINED_LOG_FORMAT],
    ]
    @root = File.expand_path(root)
    @server = WEBrick::HTTPServer.new(:Port => port, :DocumentRoot => @root, :BindAddress => "0.0.0.0", :AccessLog => access_log, :ServerName => "172.17.0.42:6400")
    puts YAML.dump(@server)
    trap 'INT' do
      puts "Received INT.. shutting down server"
      @server.shutdown
    end
    a = @server.mount '/upload', UploadFile, @root + "/uploads", @root, self
    puts YAML.dump(a)


  end

  def registerProject(project)
    @Project = project
  end
  def start()
    puts "We got a result from server.start.."
    res = @server.start
    puts YAML.dump(res)
  end


end
