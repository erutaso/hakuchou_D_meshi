# -*- coding: utf-8 -*-

require 'twitter'
require 'date'
require './key2.rb'

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
@last_update = nil
@name        = Const::SCREEN_NAME

def get_menu(status)
  
  matches = status.text.match(/([０-９0-9]+|今|明|明々*後)日[ の]?(.)/)
  return unless matches
  
  specified_day, specified_time = matches[1], matches[2]
  
  date    = Date.today
  end_day = Date.new(date.year, date.month, -1).day
  
  specified_day = specified_day.tr("０-９", "0-9")
  
  if specified_day =~ /[0-9]+/
    day = specified_day.to_i
  else
    d   = date.day
    day = d + 0
    day = d + 1 if specified_day == "明"
    day = d + 2 +  specified_day.count("々") if specified_day =~ /明々*後/
  end

  raise "今日は月末です。献立表の更新までお待ちください。" if day > end_day
  
  menu = "./#{@dic[specified_time]}.txt"
  
  return read_menufile(menu, day)

end

def tweet(body, object = nil)
  
  if object
    if object.text =~ /(@|＠)#{@name}(?!\w)/
      opt = {"in_reply_to_status_id" => object.id.to_s}
      tweet = "@#{object.user.screen_name} #{body}"
    end
  else
    opt   = {}
    tweet = body
  end
  
  @rest_client.update tweet, opt
  
end

def is_reply(text)
  return text.include?(@name)
end

def follow
  
  follower_ids = []
  @rest_client.follower_ids("#{@name}").each { |id| follower_ids.push(id) }
  
  friend_ids   = []
  @rest_client.friend_ids("#{@name}").each { |id| friend_ids.push(id) }
  
  protect_ids  = []
  @rest_client.friendships_outgoing.each { |id |protect_ids.push(id) }
  
  @rest_client.follow(follower_ids - friend_ids - protect_ids)

end

def auto
  
  d     = DateTime.now
  today = Date.today.day
  
  return if @last_update and @last_update.hour == d.hour

  time = "朝" if d.hour == 07
  time = "昼" if d.hour == 11
  time = "夜" if d.hour == 17
  follow      if d.hour == 00

  if time
    
    menu       = "./#{@dic[time]}.txt"
    today_menu = read_menufile(menu, today)
    body       = "#{d.month}月#{d.day}日の#{time}の献立は#{today_menu}です。"
    
    tweet(body)

  end
  
  @last_update = d
  
end

def read_menufile(filename, day)
  open(filename){ |file|
    return file.readlines[day - 1]
  }
end

Thread.new(){
  while true
    puts "ok #{DateTime.now}"
    auto
    sleep(10)
  end
}

@stream_client.user do |object|
  next unless object.is_a? Twitter::Tweet
  unless object.text.start_with? "RT"
    if is_reply(object.text)
      begin
        tweet_body = get_menu(object)
      rescue => e
        puts e
        tweet_body = e
      ensure
        tweet(tweet_body, object)
      end
    end
  end
end
