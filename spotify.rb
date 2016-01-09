#!/usr/bin/ruby
require 'active_record'
require 'fileutils'
require 'json'
require "net/http"
require "uri"

SAVE_DIR = File.expand_path File.dirname(__FILE__)

class ApiQuery < ActiveRecord::Base
  self.primary_key = 'api_query_id'
end

class Song < ActiveRecord::Base
  self.primary_key = 'song_id'
  has_one :api_query, foreign_key: 'song_source_num', primary_key: 'source_num'
end

ActiveRecord::Base.establish_connection({
  adapter:  'postgresql',
  database: 'postgres',
  host:     'localhost',
  username: 'postgres',
  encoding: 'unicode',
})

def set_cover_image_url! api_query
  response = JSON.parse(api_query.response_json)

  begin
    track = response['tracks']['items'][0]
  rescue NoMethodError
    p response
    raise
  end
  return if track == nil

  begin
    album = track['album'] || track['albums']['items'][0]
  rescue NoMethodError
    p track
    raise
  end

  begin
    image64 = album['images'].find { |image| (image['width'] - 64).abs <= 1 || (image['height'] - 64).abs <= 1 }
  rescue NoMethodError
    p album
    raise
  end
  return if image64.nil?

  api_query.cover_image_url = image64['url']
  api_query.save!
end

def set_album_cover_path! api_query
  return if api_query.cover_image_url.nil?

  FileUtils.mkdir_p "#{SAVE_DIR}/spotify_album_covers"
  filename = api_query.cover_image_url.split('/').last
  path = "#{SAVE_DIR}/spotify_album_covers/#{filename}"
  File.open "spotify_album_covers/#{filename}", 'w' do |file|
    file.write Net::HTTP.get(URI.parse(api_query.cover_image_url))
  end
  api_query.album_cover_path = path
  api_query.save!
end

ApiQuery.where(cover_image_url: nil).each do |api_query|
  set_cover_image_url! api_query
end
ApiQuery.where(album_cover_path: nil).each do |api_query|
  set_album_cover_path! api_query
end

while true
  song = Song.joins("LEFT JOIN api_queries ON api_queries.song_source_num = source_num").where('response_json is null').where("songs.song_name not like '%!%'").first
  break if song.nil?
  p song

  #uri = URI.parse(sprintf("https://api.spotify.com/v1/search?q=artist:%s&track:%s&type=album", URI.escape(song.artist_name), URI.escape(song.song_name)))
  #uri = URI.parse(sprintf("https://api.spotify.com/v1/search?q=artist:%s&track:%s&type=track", URI.escape(song.artist_name), URI.escape(song.song_name)))
  uri = URI.parse(sprintf("https://api.spotify.com/v1/search?q=artist:%s+track:%s&type=track", URI.escape(song.artist_name), URI.escape(song.song_name)))
  puts uri
  response = Net::HTTP.get_response(uri)
  p response
  if response.code == '200'
    api_query = ApiQuery.create!({
      song_source_num: song.source_num,
      api_name: 'spotify',
      artist_name: song.artist_name,
      song_name: song.song_name,
      response_status_code: response.code,
      response_json: response.body,
    })
    set_cover_image_url! api_query
    set_album_cover_path! api_query
  else
    p response.body
    exit 1
  end

  sleep 1
end
