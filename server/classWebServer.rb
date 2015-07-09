require 'webrick'
require 'yaml'

class UploadBase < WEBrick::HTTPServlet::AbstractServlet
  def getParams(request)
    rq = request.query()
    params = Hash.new;
    rq.each do |key,val|
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
    dir = File.expand_path("#{@tempDir}/#{params["resumableIdentifier"]}")
    #chunk path based on the parameters
    chunk = "#{dir}/#{params["resumableFilename"]}.part#{params["resumableChunkNumber"]}"
    puts "Checking existince of #{chunk}"
    if File.exists?(chunk)
      #Let resumable.js know this chunk already exists
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = "Exists!"
    else
      #Let resumable.js know this chunk doesnt exists and needs to be uploaded
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
    dir = File.expand_path("#{@tempDir}/#{params["resumableIdentifier"]}")
    #chunk path based on the parameters
    chunk = "#{dir}/#{params["resumableFilename"]}.part#{params["resumableChunkNumber"]}"

    # Create chunks directory when not present on system
    if !File.directory?(dir)
      FileUtils.mkdir(dir, :mode => 0700)
    end

    # Write the chunk out to a file
    chunkFile = File.open(chunk, "wb")
    chunkFile.write(params["file"])
    chunkFile.fsync()
    chunkFile.close()
    params["file"] = nil

    currentSize = params["resumableChunkNumber"].to_i * params["resumableChunkSize"].to_i
    filesize = params["resumableTotalSize"].to_i

    #When all chunks are uploaded
    #Concatenate all the partial files into the original file
    if (currentSize + params["resumableCurrentChunkSize"].to_i) >= filesize
      #Create a target file
      targetFile = File.open("#{dir}/#{params["resumableFilename"]}","a+b")
      if (!targetFile)
        response.status = 500
        response['Content-Type'] = 'text/plain'
        response.body = "Unable to create targetFile #{dir}/#{params["resumableFilename"]}"
        response['Access-Control-Allow-Origin'] = "*"
        return
      end

      #Loop trough the chunks
      for i in 1..params["resumableChunkNumber"].to_i
        #Select the chunk
        chunk = File.open("#{dir}/#{params["resumableFilename"]}.part#{i}", 'rb')
        #Write chunk into target file
        targetFile.write(chunk.read)
        chunk.close()
        #Deleting chunk
        FileUtils.rm "#{dir}/#{params["resumableFilename"]}.part#{i}", :force => true
      end
      puts "File saved to #{dir}/#{params["resumableFilename"]}"
      targetFile.fsync()
      targetFile.close()
    else
      puts "Saving chunk.."
    end

    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = "Successfully saved #{params["resumableFilename"]}"
    response['Access-Control-Allow-Origin'] = "*"

  end

  def do_OPTIONS(request, response)
    puts "do_OPTIONS called"
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = "You got your options!"
    response['Access-Control-Allow-Origin'] = "*"
    response['Accept-Encoding'] = "gzip"
    m = self.methods.grep(/\Ado_([A-Z]+)\z/) {$1}
    m.sort!
    response["allow"] = m.join(",")
  end
end

class UploadFile < UploadBase
  def initialize(server, tempDir, dlDir)
    super server
    @tempDir = tempDir
    @dlDir = dlDir
  end

end


class WebServer
  def initialize (port, root)
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
    a = @server.mount '/upload', UploadFile, @root + "/tmp", @root + "/complete"
    puts YAML.dump(a)
    res = @server.start
    puts "We got a result from server.start.."
    puts YAML.dump(res)
  end
end
