# coding: utf-8
$:.unshift File.expand_path("../lib", __FILE__)

require 'sinatra'
require 'sinatra/devise'
require 'sinatra/reloader' if development?
require 'active_support/all'
require 'multi_xml'
require 'builder'

configure do
  enable :logging
end

queue = []
sessions = []
access_token = "lujBn2yur3wSnzpCkJSFQWHw6i-KnKWGpBlznPFbMinwxzUKt0ftSu5fWRngbNhu"

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
  logger.info "------POST------"
  logger.info params
  logger.info "------BODY------"
  #logger.info "REQUEST CLASS: #{request.class}" # Sinatra::Request < Rack::Request
  #logger.info "BODY: #{request.body}" # StringIO < Data < Object
  #logger.info "BODY.READ: #{request.body.read}" # String
  req_msg = MultiXml.parse(request.body.read)['xml']
  logger.info "REQ: #{req_msg}"
  authorize!

  logger.info "PASSED"

  # RESPONSE

  uid = req_msg["FromUserName"]
  req_origin_msg = req_msg["Content"]

  # if uid in sessions
  #   if msg == 'kill session'
  #     kill session
  #   else
  #     repost msg to his chatter
  #   end
  # else
  #   if msg == 'start'
  #     if queue empty
  #       put uid into queue
  #     else
  #       setup a session, remove the waiting person from queue
  #     end
  #   else
  #     return tips
  #   end
  # end

  idx = sessions.map{|s| s[0]}.index(uid) || sessions.map{|s| s[1]}.index(uid)

  if !idx.nil? # in sessions
    session = sessions.delete_at(idx)
    uid1 = session[0] == uid ? session[1] : session[0]
    if req_origin_msg == "bye"
      # kill session
      m = "[SYS]对话已结束"

      # push ending message to uid1
      res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{access_token}", :body => {
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
      res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{access_token}", :body => {
        :touser => uid1,
        :msgtype => "text",
        :text => {
          :content => req_origin_msg
        }
      }.to_json)

      logger.info "pushing msg..."
      logger.info res
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
        uid1 = queue.unshift

        # push msg to uid1
        res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{access_token}", :body => {
          :touser => uid1,
          :msgtype => "text",
          :text => {
            :content => m
          }
        }.to_json)

        logger.info "pushing msg..."
        logger.info "uid: #{uid1}"
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
