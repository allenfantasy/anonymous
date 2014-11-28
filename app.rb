# coding: utf-8
$:.unshift File.expand_path("../lib", __FILE__)

require 'sinatra'
require 'sinatra/devise'
require 'sinatra/reloader' if development?
require 'active_support/all'
require 'multi_xml'
require 'builder'
require 'pry'
require './settings'

configure do
  enable :logging

  # load settings
  Sinatra::Application.class_eval do
    env = self.settings.environment
    Settings[env].keys.each do |key|
      puts key
      define_singleton key.to_sym do
        Settings[env][key]
      end
    end
  end

  # In production update the latest token
  if production?
    token_res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{settings.appid}&secret=#{settings.appsecret}")
    set :access_token, token_res.parsed_response["access_token"]
  end

  set :token_timestamp, Time.now
end

queue = []
sessions = []

get '/' do
  logger.info "------GET HOME------"
  logger.info params
  "Hello Sinatra!"
end

get '/wechat' do
  logger.info "------VERIFY------"
  logger.info params
  authorize!
  params["echostr"]
end

post '/wechat' do
  req_msg = MultiXml.parse(request.body.read)['xml']
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
      # update expired token if needed
      if Time.now - settings.token_timestamp > 7200 # expired
        token_res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{settings.appid}&secret=#{settings.appsecret}")

        set :access_token, token_res.parsed_response["access_token"]
        set :token_timestamp, Time.now
      end

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
      puts settings.access_token
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
