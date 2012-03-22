require 'active_support/time'
require 'bing_translator'
require 'builder'
require 'json'
require 'open-uri'
require 'rss/1.0'
require 'rss/2.0'
require 'sinatra'

USER_AGENT = "Mozilla/5.0 (compatible; RSSmutate/0.1; +http://github.com/6/rss-mutate-proxy)"

get '/' do
  haml :index
end

get '/mutate' do
  rss = get_rss params[:feed], params[:twitter], params[:facebook]
  halt 400, "Invalid URL or RSS content" if rss.nil?
  translator = BingTranslator.new ENV['BING_APP_ID']

  builder do |xml|
    xml.instruct! :xml, :version => '1.0'
    xml.rss :version => "2.0" do
      xml.channel do
        xml.title rss.channel.title
        xml.description rss.channel.description
        xml.link rss.channel.link
        xml.pubDate change_time_zone(rss.channel.date, params[:zone]) unless rss.channel.date.nil?
        xml.lastBuildDate change_time_zone(rss.channel.lastBuildDate, params[:zone]) unless rss.channel.lastBuildDate.nil?
        xml.language rss.channel.language unless rss.channel.language.nil?
        xml.ttl rss.channel.ttl unless rss.channel.ttl.nil?

        rss.items.each do |item|
          title = translate(translator, item.title, params[:from_lang], params[:to_lang])
          next if blacklisted?(title, params[:title_blacklist])
          xml.item do
            xml.title title
            xml.description item.description
            xml.link item.link unless item.link.nil?
            xml.pubDate change_time_zone(item.date, params[:zone]) unless item.date.nil?
            xml.author item.author unless item.author.nil?
          end
        end
      end
    end
  end
end

def get_rss(url, twitter, facebook)
  url = "https://api.twitter.com/1/statuses/user_timeline.rss?screen_name=#{twitter}" unless twitter.empty?
  url = facebook_feed_url facebook unless facebook.empty?
  url = "http://#{url}" unless /^[^:]+:\/\//.match url
  content = nil
  begin
    open(url, "User-Agent" => USER_AGENT){|s| content = s.read}
    RSS::Parser.parse(content, false)
  rescue
    nil
  end
end

def facebook_feed_url(namespace)
  begin
    open("http://graph.facebook.com/#{namespace}", "User-Agent" => USER_AGENT){|s|
      info = JSON.parse(s.read)
      "https://www.facebook.com/feeds/page.php?id=#{info['id']}&format=rss20"
    }
  rescue
    nil
  end
end

def change_time_zone(time, new_zone)
  return time if new_zone.empty?
  begin
    time.in_time_zone(new_zone.to_i).strftime("%a, %d %b %Y %H:%M:%S %z")
  rescue
    time
  end
end

def translate(translator, text, from, to)
  return text if from.empty? or to.empty? or text.empty?
  translated = translator.translate text, :from => from, :to => to
  "#{text} => #{translated}"
end

def blacklisted?(title, blacklist)
  blacklist.split(",").each{|w|
    return true if /\b#{Regexp.quote w}\b/.match title.downcase
  }
  false
end

__END__
@@ index
%title RSS mutate
<style>input[type='text']{width:200px}</style>
%form{:method => "get", :action => "/mutate"}
  %small Enter one
  %br
  %input{:type => "text", :name => "feed", :placeholder => "RSS URL"}
  or
  %input{:type => "text", :name => "twitter", :placeholder => "Twitter handle"}
  or
  %input{:type => "text", :name => "facebook", :placeholder => "Facebook Page namespace or ID"}
  %hr
  %p{:style => "font-weight:bold"} Modifications (optional)
  %small Convert time zones
  %br
  %input{:type => "text", :name => "zone", :placeholder => "UTC offset (e.g. -5)"}
  %p
    %small Translate titles
    %br
    %input{:type => "text", :name => "from_lang", :placeholder => "Translate from (e.g. fr)"}
    %input{:type => "text", :name => "to_lang", :placeholder => "Translate to (e.g. en)"}
  %p{:style => "font-weight:bold"} Filters (optional)
  %p
    %small Title blacklist keywords
    %br
    %input{:type => "text", :name => "title_blacklist", :placeholder => "Comma-separated (e.g. ipad,css3)"}
  %input{:type => "submit"}
