# coding: utf-8
$:.unshift File.expand_path("../lib", __FILE__)

require 'sinatra'
require 'sinatra/devise'
require 'sinatra/reloader' if development?
require 'active_support/all'
require 'multi_xml'
require 'builder'
require 'whenever'

configure do
  enable :logging

  set :appid, "wxcabc0cd7000f0d70"
  set :appsecret, "757b330edc8ead6e7f6d552c32a9cd1a"

  # update the latest one
  token_res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{settings.appid}&secret=#{settings.appsecret}")

  logger.info token_res

  set :access_token,"_rUNSg3KSAN9vhAdQdifME5uDfzLKcjvwp9CYuVY-C0W7Df9IQ87YWDvXP5NbMUn"
  set :token_timestamp, Time.now
end

queue = []
sessions = []
#access_token = "N1p25_BBWE4hVad1AcrPK48IMhU_oEZvSbjcDw3qI8HVQ3jRVdnx8fyg1GZhD8wR"

#Thread.new do
  #loop do
    #sleep 30
    #token_res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{appid}&secret=#{secret}")
    #logger.info "grep token"
    #logger.info res
  #end
#end
#every 30.second do
  #res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{appid}&secret=#{secret}")
  #logger.info "grep token"
  #logger.info res
#end

get '/' do
  logger.info "------GET HOME------"
  logger.info params
  "Hello Sinatra!"
end

get '/wechat' do
  logger.info "------VERIFY------"
  logger.info params
  params["echostr"]
end

post '/wechat' do
  #logger.info "------POST------"
  #logger.info params
  #logger.info "------BODY------"
  #logger.info "REQUEST CLASS: #{request.class}" # Sinatra::Request < Rack::Request
  #logger.info "BODY: #{request.body}" # StringIO < Data < Object
  #logger.info "BODY.READ: #{request.body.read}" # String
  req_msg = MultiXml.parse(request.body.read)['xml']
  #logger.info "REQ: #{req_msg}"
  authorize!

  # processing messages

  uid = req_msg["FromUserName"]
  req_origin_msg = req_msg["Content"]
  logger.info "------INIT------"
  logger.info "Queue: #{queue}"
  logger.info "Sessions: #{sessions}"
  #logger.info "Access token: #{access_token}"
  logger.info "Token Response: #{settings.access_token}"

  idx = sessions.map{|s| s[0]}.index(uid) || sessions.map{|s| s[1]}.index(uid)

  if !idx.nil? # in sessions
    if req_origin_msg == "bye"
      # kill session
      m = "[SYS]对话已结束"
      session = sessions.delete_at(idx)
      uid1 = session[0] == uid ? session[1] : session[0]

      # push ending message to uid1
      res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{settings.access_token}", :body => {
        :touser => uid1,
        :msgtype => "text",
        :text => {
          :content => m
        }
      }.to_json)

      logger.info "pushing msg..."
      logger.info res
    else
      # repost
      session = sessions[idx]
      uid1 = session[0] == uid ? session[1] : session[0]
      res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{settings.access_token}", :body => {
        :touser => uid1,
        :msgtype => "text",
        :text => {
          :content => req_origin_msg
        }
      }.to_json)

      logger.info "------REPOST------"
      logger.info "Queue: #{queue}"
      logger.info "Sessions: #{sessions}"

      #logger.info "pushing msg..."
      #logger.info res
    end
  else
    if req_origin_msg == "start"
      if queue.include?(uid)
        # duplicate request
        m = "[SYS]你已在等待队列中啦，请耐心等待另一位陌生人"
      elsif queue.empty?
        # no available chatter
        m = "[SYS]你已进入等待队列！请耐心等待~"
        queue.push(uid)
      else
        m = "[SYS]已建立对话"
        uid1 = queue.shift

        # push msg to uid1
        res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{settings.access_token}", :body => {
          :touser => uid1,
          :msgtype => "text",
          :text => {
            :content => m
          }
        }.to_json)

        logger.info "pushing msg..."
        logger.info res

        # setup a session
        sessions.push([uid, uid1])
      end
    else
      m = "[SYS]请输入start开始聊天"
    end
  end

  # setup return msg to request client
  res_msg = {
    "ToUserName" => req_msg["FromUserName"], "FromUserName" => req_msg["ToUserName"],
    "CreateTime" => Time.now.to_i, # unix timestamp
    "MsgType" => 'text',
    "Content" => m
  }.to_xml(:root => "xml")

end
