# encoding: utf-8

require 'rubygems' unless defined? Gem # rubygems is only needed in 1.8
require_relative "bundle/bundler/setup"
require "alfred"
require "unicode"
require "uri"
require 'json'
require 'net/http'

Alfred.with_friendly_error do |alfred|
  fb = alfred.feedback

  cache_json_file_path = 'cache.json'
  query = ARGV[0].to_s.strip.force_encoding('UTF-8')

  app_uri = ""
  yql_query = URI.escape("select * from html where url='http://www.adventar.org/' and xpath='//div[@data-react-class=\"CalendarList\"]'")
  yql_uri = "https://query.yahooapis.com/v1/public/yql?q=#{yql_query}&format=json&diagnostics=true&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback="
  parsed_yql_uri = URI.parse(yql_uri)

  icon = {
    :img => {
      :type => "default",
      :name => "icon.png"
    }
  }

  default_item = {
    :uid      => "",
    :title    => "見つかりませんでした",
    :subtitle => "別の検索条件でお探しください",
    :arg      => app_uri,
    :icon     => icon[:img]
  }

  # キャッシュが存在しない、または、キャッシュが1日前だったら
  if !File.exist?(cache_json_file_path) || (DateTime.now.to_time - File.mtime(cache_json_file_path)) >= 86400
    https = Net::HTTP.new(parsed_yql_uri.host, parsed_yql_uri.port)
    https.use_ssl = true
    res = https.start {
      https.get(parsed_yql_uri.request_uri)
    }
    if res.code == '200'
      result = JSON.parse(res.body)
      calendars_json = JSON.parse(result["query"]["results"]["div"]["data-react-props"])
      open(cache_json_file_path, 'w') do |io|
        JSON.dump(calendars_json, io)
      end
    end
  end

  json_data = open(cache_json_file_path) do |io|
    JSON.load(io)
  end

  if json_data
    calendars = json_data["calendars"]
    if calendars.length != 0
      if query
        calendars = calendars.select { |item| /#{query}/i =~ item["title"] }
      end
      calendars.each do | item |
        fb.add_item({
          :uid      => item["id"],
          :title    => "#{item['title']} Advent Calendar",
          :subtitle => "#{item['count']}/25人 #{item['title']}",
          :arg      => "http://www.adventar.org/calendars/#{item['id']}",
          :icon     => icon[:img]
        })
      end
    else
      fb.add_item(default_item)
    end
    puts fb.to_xml()
  else
    fb.add_item(default_item)
    puts fb.to_xml()
  end

end
