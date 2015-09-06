#!/usr/bin/env ruby
require "date"
require "httparty"
require "trollop"
require 'ruby-prof'

require 'active_support'
require "active_support/core_ext/array/grouping"

def format_episode(episode)
  if episode < 10
    "00#{episode}"
  elsif episode < 100
    "0#{episode}"
  else
    episode.to_s
  end
end

def format_url(padded_episode)
  @url_frag.gsub(":ep", padded_episode).gsub(":time_stamp", "#{Time.now.tv_sec}#{Time.now.tv_usec}")
end

def episodes_number
  @episodes_number ||= @opts[:to] - @opts[:from]
end

def check_args
  Trollop::die :from, "must be non negative" if @opts[:from] < 0
  Trollop::die :to, "must be an integer >= 1" if @opts[:to] == nil || @opts[:to] < 1
  Trollop::die :to, "must be greater or equal to episode from" if @opts[:to] < @opts[:from]
  Trollop::die :threaded, "must be and integer >=1" if @opts[:threaded] < 1 
  Trollop::die :threaded, "must be less or equal to number of downloaded files" if @opts[:threaded] > @opts[:to]   
end

def create_download_directory
  unless FileTest::directory?("episodes")
    Dir::mkdir("episodes")
  end
end

def download
  puts "downloading ruby5 podcasts"

  File.open(@log_filename, "a") do |lf|
    lf.puts "Start downloading ruby5 episodes - #{DateTime.now.to_s}"
    lf.puts "="*10

    threads = []
    (@opts[:from]..@opts[:to]).to_a.in_groups(@opts[:threaded], false) do |sr|  
      threads << Thread.new(sr) do |sr|
        sr.each do |ep|
          ep_str = format_episode(ep)
          url = format_url(ep_str)
          format_filename = @out_filename.gsub(":ep", ep_str)

          if File.exist?(format_filename) && @opts[:force] != true
            puts "skipping episode #{ep_str} as it exists"
            lf.puts "episode #{ep_str}.mp3 skipped"
          else 
            puts "starting episode #{ep_str} - #{url}"
            response = HTTParty.get(url)
            if response.code == 200
              File.open(format_filename, "wb") { |f| f.write(response) }
              puts "download complete for episode #{ep_str}"
              lf.puts "episode #{ep_str}.mp3 successfully downloaded"
            elsif
              puts "download not completed for episode #{ep_str} - code #{response.code}"
              lf.puts "error downloading episode #{ep_str}.mp3"
            end
            puts "#{"-"*10}#{("\n")*2}"
          end
        end
      end
    end
    threads.each {|t| t.join}
    lf.puts "Finished downloading ruby5 episodes - #{DateTime.now.to_s}"
    lf.puts "-"*10
    lf.puts "\n"*2
  end
end
@url_frag = "https://d1wqo57uhimzvc.cloudfront.net/sites/0001/episodes/:ep-ruby5.mp3?:time_stamp"
@out_filename = "episodes/:ep-ruby5.mp3"
@log_filename = "log.txt"
@opts = Trollop::options do
  opt :from, "Episode from", default: 1, type: :int
  opt :to, "Episode to", type: :int
  opt :threaded, 'Number of threads', default: 1, type: :int, short: '-T'
  opt :force, 'Overwrite already downloaded files', default: false, type: :bool, short: '-F'
end

start_time = Time.now

check_args
create_download_directory
download

puts "Time spent: #{Time.now - start_time}s"
