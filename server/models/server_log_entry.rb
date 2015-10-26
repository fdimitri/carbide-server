class ServerLogEntry < ActiveRecord::Base
	attr_accessor :entrytime, :flags, :source, :message
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
		logEntry = self.new(params)
		puts YAML.dump(params)
		puts YAML.dump(logEntry)
		die
			begin
				while (!logEntry.save!) do
				end
			rescue Exception => e
  				bt = caller_locations(10)
				puts YAML.dump(bt)
				puts YAML.dump(e)
				die
			end
 		return(logEntry)
	end 
end

class SLEHelper < ServerLogEntry
def initialize(params)
puts "Hi! I'm the SLE Helper!"
end

end

