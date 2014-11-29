require 'httparty'
require 'multi_xml'
require 'active_support/all'

module Sinatra
  module Wechat
    TOKEN = 'dxhackers'

    class Message
      attr_accessor :type, :my_account, :user_account, :content

      def initialize(content, received_msg)
        # String: text
        # TODO: Hash: non-text, check the type
        @type = 'text'
        puts received_msg
        @my_account = received_msg["ToUserName"]
        @user_account = received_msg["FromUserName"]
        @content = content
      end

      def to_xml
        {
          ToUserName: @user_account,
          FromUserName: @my_account,
          CreateTime: Time.now.to_i,
          MsgType: @type,
          Content: @content
        }.to_xml(:root => "xml", :skip_types => true)
      end

      def to_json
        {
          :touser => @user_account,
          :msgtype => @type,
          :text => {
            :content => @content
          }
        }.to_json
      end
    end

    # use in main context
    module RegisterMethods
      def base_url(url=nil)
        return Wechat.base_url if url.nil?
        Wechat.base_url = url

        # set basic route
        
        get url do
          authorize!
          params["echostr"]
        end

        post url do
          authorize!
          wechat_params = parse(request)
          result = send(:"#{wechat_params['MsgType'].downcase}_handler", wechat_params)
          puts result
          return_msg = Wechat::Message.new(result, wechat_params)
          return_msg.to_xml
        end
      end

      def on(type)
        return unless block_given?
        type = type.to_s.downcase

        HelperMethods.send :define_method, :"#{type}_handler" do |params|
          yield params
        end
      end

      def push(me, name, content, access_token)
        msg = Wechat::Message.new(content, {
          "FromUserName" => me,
          "ToUserName" => name
        })
        res = HTTParty.post(push_message_api(access_token), :body => msg.to_json)
      end

      class << Wechat
        attr_accessor :base_url
      end

      private
      def push_message_api(access_token)
        "https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=#{access_token}"
      end
    end
    
    # use in get/post/.. blocks
    module HelperMethods
      def authorize!
        nonce, timestamp, signature = params[:nonce], params[:timestamp], params[:signature]
        if [nonce, timestamp, signature].compact.size < 3 or signature != genarate_signature(TOKEN, nonce, timestamp)
          logger.info "FAILED"
          halt 401, "Forbidden! You Bastards!"
        end
      end
      def parse(request)
        MultiXml.parse(request.body.read)["xml"]
      end

      def method_missing(method, *args)
        "Hello, this is the default message"
      end

      private
      def genarate_signature(token, nonce, timestamp)
        Digest::SHA1.hexdigest([token, nonce, timestamp].sort.join)
      end
    end

  end

  register Wechat::RegisterMethods
  helpers Wechat::HelperMethods
end
