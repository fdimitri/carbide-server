class Project < ActiveRecord::Base
        establish_connection   :adapter => 'mysql2', :database => 'carbide-client-alpha0', :encoding => 'utf8',
        :username => 'root', :password => 'bu:tln563', :socket => '/var/run/mysqld/mysqld.sock', :timeout => 20000,
        :pool => 50, :reconnect => true

  belongs_to :Owner, class_name: "User"
  has_one :ProjectProfile, :dependent => :destroy
  accepts_nested_attributes_for :ProjectProfile,  :reject_if => :all_blank, :allow_destroy => true
  has_many :ProjectsUser
  has_many :Users, :through => :ProjectsUser
  public
  
  def has_user?(userId)
    Users.each do |user|
      if (user.id == userId)
        return true
      end
    end
    return false
  end
  
  def is_public?
    return true
  end
  
  def is_visible_to_user?(userId)
    # if self.isPublic? || self.hasUser?(userId) || 
    return true
  end
  
end
