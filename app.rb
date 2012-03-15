require 'active_support/time'
require 'builder'
require 'open-uri'
require 'rss/1.0'
require 'rss/2.0'
require 'sinatra'

get '/' do
  haml :index
end

get '/mutate' do
  halt 400, "No feed URL specified" if params[:feed].nil?
  content = nil
  begin
    open(params[:feed]){|s| content = s.read}
  rescue
    halt 400, "Invalid feed URL: #{params[:feed]}"
  end
  rss = RSS::Parser.parse(content, false)
  halt 400, "Invalid RSS content" if rss.nil?

  builder do |xml|
    xml.instruct! :xml, :version => '1.0'
    xml.rss :version => "2.0" do
      xml.channel do
        xml.title rss.channel.title
        xml.description rss.channel.description
        xml.link rss.channel.link

        rss.items.each do |item|
          xml.item do
            xml.title item.title
            xml.description item.description
            xml.link item.link unless item.link.nil?
            xml.pubDate change_time_zone(item.date, params[:zone]) unless item.date.nil?
          end
        end
      end
    end
  end
end

def change_time_zone(time, new_zone)
  return time if new_zone.nil?
  begin
    time.in_time_zone(new_zone.to_i)
  rescue
    time
  end
end

__END__
@@ index
%form{:method => "get", :action => "/mutate"}
  %input{:type => "text", :name => "feed", :placeholder => "RSS URL"}
  %p Optional:
  %input{:type => "text", :name => "zone", :placeholder => "UTC offset (e.g. -5)"}
  %input{:type => "submit"}
