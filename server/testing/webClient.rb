require 'net/http'

uri = URI('http://127.0.0.1:6400/upload')

res = Net::HTTP.post_form()
