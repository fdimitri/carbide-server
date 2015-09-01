class ProjectProfile < ActiveRecord::Base
        establish_connection   :adapter => 'mysql2', :database => 'carbide-client-alpha0', :encoding => 'utf8',
        :username => 'root', :password => 'bu:tln563', :socket => '/var/run/mysqld/mysqld.sock', :timeout => 20000,
        :pool => 50, :reconnect => true

  belongs_to :Project
end
