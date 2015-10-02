require 'mysql2'

puts "Loaded gems:"
puts Gem.loaded_specs.values.map {|x| "#{x.name} #{x.version}"}

class ClientARBOR < ActiveRecord::Base
	ActiveRecord::Base.establish_connection   :adapter => "mysql2", :database => 'carbide-client-alpha0', :encoding => 'utf8', 
	:username => 'root', :password => 'bu:tln563', :socket => '/var/lib/mysql/mysql.sock', :timeout => 20000, 
	:pool => 50, :reconnect => true
end
