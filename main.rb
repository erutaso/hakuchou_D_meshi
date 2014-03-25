# -*- coding: utf-8 -*-

require 'twitter'
require 'date'
require 'nkf'
require './key.rb'


@rest_client = Twitter::REST::Client.new do |config|
  config.consumer_key        = Const::CONSUMER_KEY
  config.consumer_secret     = Const::CONSUMER_SECRET
  config.access_token        = Const::ACCESS_TOKEN
  config.access_token_secret = Const::ACCESS_TOKEN_SECRET
end

@stream_client = Twitter::Streaming::Client.new do |config|
  config.consumer_key        = Const::CONSUMER_KEY
  config.consumer_secret     = Const::CONSUMER_SECRET
  config.access_token        = Const::ACCESS_TOKEN
  config.access_token_secret = Const::ACCESS_TOKEN_SECRET
end


@dic         = {'朝' => 'first', '昼' => 'second', '夜' => 'third'}
@today       = Date.today
@last_update = nil
@name        = Const::SCREEN_NAME

def meshi(status)

  @dic.each{ |key, value|
    if status.text.include?("@#{name} #{key}")

      menu = "./#{value}.txt"

      text = status.text.sub("@#{name} #{key}","")
      text = text.gsub(/(\s|　)+/, "")
      text = text.gsub(/日/,"")
      text = NKF.nkf('-m0Z1 -w',text)

      case text
      when /今/ 
        open(menu){ |file|
          body =  file.readlines[@today.day - 1]
        }
      when /明/
        if @today.day == Date.new(@today.year, @today.month, -1).day
          body = "今日は月末です。献立表の更新までお待ちください。"
        else
          open(menu){ |file|
            body = file.readlines[@today.day]
          }
        end
      else
        open(menu){ |file|
          body = file.readlines[text.to_i - 1]
        }
      end
      
      opt = {"in_reply_to_status_id"=>status.id.to_s}
      tweet = "@#{status.user.screen_name} #{body}"
      @rest_client.update tweet,opt

    end
  }
end


def follow
  
  follower_ids = []
  @rest_client.follower_ids("#{name}").each do |id|
    follower_ids.push(id)
  end
  
  friend_ids   = []
  @rest_client.friend_ids("#{name}").each do |id|
    friend_ids.push(id)
  end
  
  protect_ids  = []
  @rest_client.friendships_outgoing.each do |id|
    protect_ids.push(id)
  end

  @rest_client.follow(follower_ids - friend_ids - protect_ids)

end


def tweet

  d = DateTime.now
  
  return if @last_update and @last_update.hour == d.hour
  
  if d.hour == 07
    open("./first.txt"){ |file|
      @fare = file.readlines[@today.day - 1]
    }
    time = "朝"
  end
  
  if d.hour == 11
    open("./second.txt"){ |file|
      @fare = file.readlines[@today.day - 1]
    }
    time = "昼"
  end
  
  if d.hour == 17
    open("./third.txt"){ |file|
      @fare = file.readlines[@today.day - 1]
    }
    time = "夜"
  end
  
  if d.hour == 00
    follow
  end

  if time
    @rest_client.update("#{d.month}月#{d.day}日の#{time}の献立は#{@fare}です。")
  end
  
  @last_update = d    
  
end


Thread.new(){
  while true
    puts "ok #{DateTime.now}"
    tweet
    sleep(10)
  end
}


@stream_client.user do |object|
  next unless object.is_a? Twitter::Tweet
  unless object.text.start_with? "RT"
    meshi(object)
  end
end
