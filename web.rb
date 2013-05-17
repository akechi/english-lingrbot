# -*- coding: utf-8 -*-
require 'bundler'
Dir.chdir File.dirname(__FILE__)
Bundler.require
set :environment, :production

get '/' do
  'hello'
end

def escape(s)
  REXML::Text::normalize(s)
end

def translate(from, to, text)
  key = ENV['ENGLISH_BOT_USER_KEY']
  ret = ''
  open("https://api.datamarket.azure.com/Bing/MicrosoftTranslator/Translate()?From='#{escape(from)}'&To='#{escape(to)}'&Text='#{escape(text)}'", :http_basic_authentication => [key, key]) do |f|
    doc = REXML::Document.new f
    doc.elements.each("//content//d:Text") do |elem|
      ret += "#{REXML::Text::unnormalize(elem.text)}\n"
    end
  end
  return ret
end

def ginger(en)
  ret = ''
  open("http://services.gingersoftware.com/Ginger/correct/json/GingerTheText?#{URI.encode_www_form({
    'lang'          => 'US',
    'clientVersion' => '2.0',
    'apiKey'        => ENV['ENGLISH_BOT_API_KEY'],
    'text'          => en})}") do |f|
    res = JSON.parse(f.read)
    i = 0
    correct = ''
    res['LightGingerTheTextResult'].each do |rs|
      from, to = rs['From'], rs['To']
      correct += en[i...from] if i < from
      correct += rs['Suggestions'][0]['Text']
      i = to + 1
    end
    correct += en[i..-1] if i < en.size
    ret += "#{correct}\n"
  end
  return ret
end

post '/lingr' do
  json = JSON.parse(request.body.string)
  ret = ''
  json['events'].each do |e|
    text = e['message']['text']
    if text =~ /^!honyaku\s+(.*)$/
      ret += "#{translate('en', 'ja', $1)}\n"
    elsif text =~ /^!translate\s+(\S+)\s+(\S+)\s+(.*)$/
      ret += "#{translate($1, $2, $3)}\n"
    elsif text =~ /^!ginger\s+(.+)$/
      ret += "#{ginger($1)}\n"
    end
  end
  ret.rstrip
end
