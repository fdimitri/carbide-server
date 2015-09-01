class ProjectsUser < ActiveRecord::Base
        establish_connection   :adapter => 'mysql2', :database => 'carbide-client-alpha0', :encoding => 'utf8',
        :username => 'root', :password => 'bu:tln563', :socket => '/var/run/mysqld/mysqld.sock', :timeout => 20000,
        :pool => 50, :reconnect => true

  belongs_to :User
  belongs_to :Project
  has_one :Initiator, class_name: "User"
  validates :User_id, uniqueness: { scope: :Project_id, message: "Cannot have identical user/project pairs" }
  validates :Project_id, uniqueness: { scope: :User_id, message: "Cannot have identical user/project pairs" }
  def all(userId = nil)
    rlist = []
    tlist = ProjectsUser.with_exclusive_scope { find(:all) }
    if (userId == nil)
      return tlist
    end
    tlist.each do |pu_assoc|
      if pu_assoc.Project.is_visible_to_user?(userId)
        rlist << pu_assoc
      end
    end
    return rlist
  end
end
