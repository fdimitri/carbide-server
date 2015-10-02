class Identity < ActiveRecord::Base
        establish_connection   :adapter => 'mysql2', :database => 'carbide-client-alpha0', :encoding => 'utf8',
        :username => 'root', :password => 'bu:tln563', :socket => '/var/lib/mysql/mysql.sock', :timeout => 20000,
        :pool => 50, :reconnect => true

  belongs_to :user
  validates_presence_of :uid, :provider
  validates_uniqueness_of :uid, :scope => :provider

  def self.find_for_oauth(auth)
    find_or_create_by(uid: auth.uid, provider: auth.provider)
  end
end
