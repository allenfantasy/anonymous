require './app'
require 'httparty'

appid = "wxcabc0cd7000f0d70"
secret = "757b330edc8ead6e7f6d552c32a9cd1a"

task :update_token do
  res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{appid}&secret=#{secret}")
end
