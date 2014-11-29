# coding: utf-8
$:.unshift File.expand_path("../lib", __FILE__)

require 'sinatra'
require 'sinatra/wechat'
require 'sinatra/reloader' if development?
require 'active_support/all'
require 'builder'
require 'pry'
require './settings'

configure do
  enable :logging

  # load settings
  Sinatra::Application.class_eval do
    env = self.settings.environment
    Settings[env].keys.each do |key|
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

base_url '/wechat'

get '/' do
  "Hello Sinatra!"
end

queue = [] # 等待聊天的队列
sessions = [] # 正在聊天的session

def sessions.include_user?(name)
  self.map{|s| s.values }.flatten.uniq.include? name
end

on :text do |params|
  username = params["FromUserName"]
  msg = params["Content"]
  
  in_session = sessions.include_user?(username)
  in_queue = queue.include?(username)

  if msg == "START"
    if in_session
      # 正常发一个start
    elsif in_queue 
      # 提示用户耐心等待
    else 
      # 判断queue里是否有人，有的话建立session
      # 没有的话将用户放到等待队列里
    end
  elsif msg == "BYE"
    if in_session
      # 结束当前session
    elsif in_queue
      # 将用户从queue里去掉
    else
      # 提示用户应该用start进入聊天
    end
  else
    if in_session
      # 正常聊天，将信息转发给对方
    elsif in_queue
      # 提示用户耐心等待
    else
      # 提示用户应该用start进入聊天
    end
  end
  "LOOOOL"
  #if sessions.include_user?(username)
    #"Congrats! You are in!"
    #if msg == "bye"
      ## kill session
      #m = "[SYS]对话已结束"
      #session = sessions.delete_at(idx)
      #uid1 = session[0] == uid ? session[1] : session[0]

      ## push ending message to uid1
      ## update expired token if needed
      #if Time.now - settings.token_timestamp > 7200 # expired
        #token_res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{settings.appid}&secret=#{settings.appsecret}")

        #set :access_token, token_res.parsed_response["access_token"]
        #set :token_timestamp, Time.now
      #end

      #res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{settings.access_token}", :body => {
        #:touser => uid1,
        #:msgtype => "text",
        #:text => {
          #:content => m
        #}
      #}.to_json)

      #logger.info "pushing msg..."
      #logger.info res
    #else
      ## repost
      #session = sessions[idx]
      #uid1 = session[0] == uid ? session[1] : session[0]
      #puts settings.access_token
      #res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{settings.access_token}", :body => {
        #:touser => uid1,
        #:msgtype => "text",
        #:text => {
          #:content => req_origin_msg
        #}
      #}.to_json)

      #logger.info "------REPOST------"
      #logger.info "Queue: #{queue}"
      #logger.info "Sessions: #{sessions}"

      ##logger.info "pushing msg..."
      ##logger.info res
    #end
  #else
    #"You are not in the session!"
    #if req_origin_msg == "start"
      #if queue.include?(uid)
        ## duplicate request
        #m = "[SYS]你已在等待队列中啦，请耐心等待另一位陌生人"
      #elsif queue.empty?
        ## no available chatter
        #m = "[SYS]你已进入等待队列！请耐心等待~"
        #queue.push(uid)
      #else
        #m = "[SYS]已建立对话"
        #uid1 = queue.shift

        ## push msg to uid1
        #res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{settings.access_token}", :body => {
          #:touser => uid1,
          #:msgtype => "text",
          #:text => {
            #:content => m
          #}
        #}.to_json)

        #logger.info "pushing msg..."
        #logger.info res

        ## setup a session
        #sessions.push([uid, uid1])
      #end
    #else
      #m = "[SYS]请输入start开始聊天"
    #end
  #end
  #"Hello back"
end
