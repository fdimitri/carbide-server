class ServerLogEntry < ActiveRecord::Base
	establish_connection(
	 :adapter => 'mysql2',
	 :database => 'carbide-client-alpha0', 
	 :encoding => 'utf8',
         :username => 'root', 
	 :password => 'bu:tln563', 
	 :socket => '/var/lib/mysql/mysql.sock', 
	 :timeout => 20000,
         :pool => 50, 
 	 :reconnect => true)

    def self.create(params)
        logEntry = ServerLogEntry.new(params)
        begin
            while (!logEntry.save!) do
            end
        rescue Exception => e
            puts YAML.dump(e)
        end
        return(logEntry)
    end 
end

class SLEHelper < ServerLogEntry
    def initialize(params)
        puts "Hi! I'm the SLE Helper!"
    end

end
