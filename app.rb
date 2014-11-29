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

def sessions.get_index(name)
  self.index { |s| s.include?(name) }
end

def sessions.get_opposite_user(name)
  index = self.get_index(name)
  self[index][0].name == name ? self[index][0].opposite : self[index][0].name
end

on :text do |params|
  username = params["FromUserName"]
  msg = params["Content"]
  
  in_session = sessions.include_user?(username)
  in_queue = queue.include?(username)
  session_index = sessions.index { |s| s[0] == username || s[1] == username }

  if msg == "START"
    if in_session # 正常聊天
      opposite = sessions.get_opposite_user(username)
      push(params["ToUserName"], opposite, msg, settings.access_token)
      "" # 回复空串，这样微信不会重复询问
    elsif in_queue
      "[SYS]你已在等待队列中啦，请耐心等待另一位陌生人"
    else 
      # 判断queue里是否有人，有的话建立session
      # 没有的话将用户放到等待队列里
      if queue.empty?
        queue.push(username)
        "[SYS]你已进入等待队列！请耐心等待"
      else
        system_msg = "[SYS]已建立对话，你们可以开始聊天了"
        opposite = queue.unshift
        session.push([
          { name: username, opposite: opposite },
          { name: opposite, name: username }
        ])
        push(params["ToUserName"], opposite, system_msg, settings.access_token)
        system_msg
      end
    end
  elsif msg == "BYE"
    if in_session # 结束当前session
      system_msg = "[SYS]对话已结束"
      s = sessions.delete_at(session_index)
      opposite = sessions.get_opposite_user(username)

      ## 更新过期的Token, 为了不和微信的2小时撞，改为7100ms
      if Time.now - settings.token_timestamp > 7100 # expired
        token_res = HTTParty.post("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{settings.appid}&secret=#{settings.appsecret}")

        set :access_token, token_res.parsed_response["access_token"]
        set :token_timestamp, Time.now
      end

      push(params["ToUserName"], opposite, system_msg, settings.access_token)
      system_msg
    elsif in_queue
      # 将用户从queue里去掉
      queue.delete_if { |name| name == username }
      "[SYS]你已离开等待队列，若要重新聊天请输入START"
    else
      "[SYS]请输入START进入聊天"
    end
  else
    if in_session
      # 正常聊天，将信息转发给对方
      opposite = sessions.get_opposite_user(username)
      push(params["ToUserName"], opposite, msg, settings.access_token)
      # 回复空串，这样微信不会重复询问
      ""
    elsif in_queue
      "[SYS]你已在等待队列中，请耐心等待另一位陌生人"
    else
      "[SYS]请输入START进入聊天"
    end
  end
end
