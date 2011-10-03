#!/usr/bin/ruby -w
require 'yaml'

configfile = "#{ENV['HOME']}/getpinboard.yaml"

if File.exists? configfile
  conf = open(configfile) {|f| YAML.load(f) }
else
  config = {  "target" => "#{ENV['HOME']}/Dropbox/Sync/Bookmark", 
              "user" => "pinboarduser", 
              "password" => "pinboardpass",
              "db_location" => "#{ENV['HOME']}/Dropbox/Sync/Bookmark",
              "pdf_location" => "#{ENV['HOME']}/Dropbox/Sync/WebPDF",
              "tag_method" => 1,
              "always_tag" => "pinboard",
              "update_tags_db" => true,
              "create_thumbs" => true,
              "pdf_tag" => 'pdfit',
              "debug" => false,
              "gzip_db" => false
           }
  File.open(configfile, 'w') {|f| YAML.dump(config, f)}
  exit
end


puts conf['user']