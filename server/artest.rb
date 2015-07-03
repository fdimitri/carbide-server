require 'rubygems'
require 'active_record'
require 'yaml'
require 'logger'
Dir["./models/*rb"].each {| file| require file }

ActiveRecord::Base.logger = Logger.new('debug.log')
configuration = YAML::load(IO.read('config/database.yml'))
ActiveRecord::Base.establish_connection(configuration['development'])
