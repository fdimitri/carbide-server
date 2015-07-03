class User < ActiveRecord::Base

  has_secure_password

  def password
    @password ||= BCrypt::Password.new(password_digest)
  end

  def password=(new_password)
    @password = BCrypt::Password.create(new_password)
    self.password_digest = @password
  end

  def create
    @user = User.new(params[:user])
    @user.password = params[:password]
    @user.save!
  end



end

class UserController < User
  def self.login(params)
    puts "Login called.."
    @user = User.find_by_email(params[:email])
    if (!@user)
      puts "Unable to find user with email address: #{params[:email]}"
      return FALSE
    end
    if (@user.password == params[:password])
      puts "Login for user #{@user.userName} successful"
      @authenticated = TRUE
      return @user
    else
      puts "Login for user #{@user.userName} NOT successful"
      @authenticated = FALSE
      return FALSE
    end
  end
end
