#!/usr/bin/env ruby
##############################################################################
### getpinboard.rb by Brett Terpstra, 2011 <http://brettterpstra.com>
### Retrieves Pinboard.in bookmarks, saves as local .webloc files for
### Spotlight searching.
###
### Optionally adds OpenMeta tags and/or saves page as PDF (see config below)
### Use -r [NUMBER OF DAYS] to reset the "last_checked" timestamp (primarily 
### for debugging).
###
### This script is released to the public, modify at will but please leave 
### credit
##############################################################################

def pick_editor
  editors = ['TextMate','Espresso','MacVim','Coda','TextEdit']
  ps = %x{ps Ao comm|grep .app|awk '{match($0,/([^\\/]+).app/); print substr($0,RSTART,RLENGTH)}'}.split("\n")
  editors.each {|editor|
    return editor if ps.include?(editor+".app")
  }
  return "TextEdit"
end

require 'yaml'
configfile = "#{ENV['HOME']}/getpinboard.yaml"

# If config file `getpinboard.yaml` doesn't exist in the user's home folder,
# create it, exit the script and open the config for editing.
# Otherwise, read the config and go for it.
if File.exists? configfile
  $conf = File.open(configfile) {|f| YAML.load(f) }
  if $conf['debug']
    puts "Read config from #{configfile}..."
    $conf.each {|k,v|
      puts k+": "+v.to_s
    }
  end
else
  if File.exists?('/Applications/Tags.app')
    default_tagger = 1
  elsif File.exists?('/usr/local/bin/openmeta')
    default_tagger = 2
  else
    default_tagger = 0
  end
  comments = <<-GAMEOVER
--- 
user: pinboarduser
password: pinboardpass
# (string) Pinboard user and password
#
dateformat: US
# (string) US (12-31-2011) or UK (31-12-2011)
#
target: #{ENV['HOME']}/Dropbox/Sync/Bookmark
# (absolute path) Location for webloc files
#
db_location: #{ENV['HOME']}/Dropbox/Sync/Bookmark
# (absolute path) Location for the database. Can be the same as target.
#
pdf_tag: pdfit
# (string) If this tag exists on a bookmark, save a PDF (false to disable)
# requires latest version of <http://derailer.org/paparazzi/>
#
pdf_location: #{ENV['HOME']}/Dropbox/Sync/WebPDF
# (absolute path) Location for PDF files, if pdf_tag option above is set and triggered
#
tag_method: #{default_tagger}
# (integer) OpenMeta tagging method, 0 to disable, 1 for Tags.app, 2 for openmeta
#
always_tag: pinboard
# (string) A tag to add to all saved bookmarks. set to '' for none
#
update_tags_db: #{default_tagger == 1 ? 'true' : 'false'}
# (true/false) Sync Tags.app bookmark database. If you use Tags.app, use this
#
create_thumbs: #{File.exists?('/usr/local/bin/setWeblocThumb') ? 'true' : 'false'}
# (true/false) Create thumbnail icons for webloc files.
# requires setWeblocThumb <http://hasseg.org/setWeblocThumb/>
#
debug: false
# (true/false) Only turn on if needed, adds additional status messages and responses
gzip_db: false
# (true/false) Saves some space, if you really need it
GAMEOVER
               
  File.open(configfile, 'w') {|f| 
    f.puts(comments)
  }
  editor = pick_editor
  puts "Initial configuration file written to #{configfile}, opening in #{editor}."
  %x{open -a "#{editor}.app" "#{configfile}"}
  # %x{osascript -e 'tell app "Finder" to reveal POSIX file "#{configfile}"'}
  exit
end

%w[fileutils ftools set net/https zlib rexml/document time base64 cgi stringio yaml].each do |filename|
  require filename
end

# = plist
#
# Copyright 2006-2010 Ben Bleything and Patrick May
# Distributed under the MIT License
#

module Plist ; end

# === Create a plist
# You can dump an object to a plist in one of two ways:
#
# * <tt>Plist::Emit.dump(obj)</tt>
# * <tt>obj.to_plist</tt>
#   * This requires that you mixin the <tt>Plist::Emit</tt> module, which is already done for +Array+ and +Hash+.
#
# The following Ruby classes are converted into native plist types:
#   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time, true, false
# * +Array+ and +Hash+ are both recursive; their elements will be converted into plist nodes inside the <array> and <dict> containers (respectively).
# * +IO+ (and its descendants) and +StringIO+ objects are read from and their contents placed in a <data> element.
# * User classes may implement +to_plist_node+ to dictate how they should be serialized; otherwise the object will be passed to <tt>Marshal.dump</tt> and the result placed in a <data> element.
#
# For detailed usage instructions, refer to USAGE[link:files/docs/USAGE.html] and the methods documented below.
module Plist::Emit
  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.dump</tt> with +self+.
  def to_plist(envelope = true)
    return Plist::Emit.dump(self, envelope)
  end

  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.save_plist</tt> with +self+.
  def save_plist(filename)
    Plist::Emit.save_plist(self, filename)
  end

  # The following Ruby classes are converted into native plist types:
  #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time
  #
  # Write us (via RubyForge) if you think another class can be coerced safely into one of the expected plist classes.
  #
  # +IO+ and +StringIO+ objects are encoded and placed in <data> elements; other objects are <tt>Marshal.dump</tt>'ed unless they implement +to_plist_node+.
  #
  # The +envelope+ parameters dictates whether or not the resultant plist fragment is wrapped in the normal XML/plist header and footer.  Set it to false if you only want the fragment.
  def self.dump(obj, envelope = true)
    output = plist_node(obj)

    output = wrap(output) if envelope

    return output
  end

  # Writes the serialized object's plist to the specified filename.
  def self.save_plist(obj, filename)
    File.open(filename, 'wb') do |f|
      f.write(obj.to_plist)
    end
  end

  private
  def self.plist_node(element)
    output = ''

    if element.respond_to? :to_plist_node
      output << element.to_plist_node
    else
      case element
      when Array
        if element.empty?
          output << "<array/>\n"
        else
          output << tag('array') {
            element.collect {|e| plist_node(e)}
          }
        end
      when Hash
        if element.empty?
          output << "<dict/>\n"
        else
          inner_tags = []

          element.keys.sort.each do |k|
            v = element[k]
            inner_tags << tag('key', CGI::escapeHTML(k.to_s))
            inner_tags << plist_node(v)
          end

          output << tag('dict') {
            inner_tags
          }
        end
      when true, false
        output << "<#{element}/>\n"
      when Time
        output << tag('date', element.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))
      when Date # also catches DateTime
        output << tag('date', element.strftime('%Y-%m-%dT%H:%M:%SZ'))
      when String, Symbol, Fixnum, Bignum, Integer, Float
        output << tag(element_type(element), CGI::escapeHTML(element.to_s))
      when IO, StringIO
        element.rewind
        contents = element.read
        # note that apple plists are wrapped at a different length then
        # what ruby's base64 wraps by default.
        # I used #encode64 instead of #b64encode (which allows a length arg)
        # because b64encode is b0rked and ignores the length arg.
        data = "\n"
        Base64::encode64(contents).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
        output << tag('data', data)
      else
        output << comment( 'The <data> element below contains a Ruby object which has been serialized with Marshal.dump.' )
        data = "\n"
        Base64::encode64(Marshal.dump(element)).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
        output << tag('data', data )
      end
    end

    return output
  end

  def self.comment(content)
    return "<!-- #{content} -->\n"
  end

  def self.tag(type, contents = '', &block)
    out = nil

    if block_given?
      out = IndentedString.new
      out << "<#{type}>"
      out.raise_indent

      out << block.call

      out.lower_indent
      out << "</#{type}>"
    else
      out = "<#{type}>#{contents.to_s}</#{type}>\n"
    end

    return out.to_s
  end

  def self.wrap(contents)
    output = ''

    output << '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
    output << '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' + "\n"
    output << '<plist version="1.0">' + "\n"

    output << contents

    output << '</plist>' + "\n"

    return output
  end

  def self.element_type(item)
    case item
    when String, Symbol
      'string'

    when Fixnum, Bignum, Integer
      'integer'

    when Float
      'real'

    else
      raise "Don't know about this data type... something must be wrong!"
    end
  end
  private
  class IndentedString #:nodoc:
    attr_accessor :indent_string

    def initialize(str = "\t")
      @indent_string = str
      @contents = ''
      @indent_level = 0
    end

    def to_s
      return @contents
    end

    def raise_indent
      @indent_level += 1
    end

    def lower_indent
      @indent_level -= 1 if @indent_level > 0
    end

    def <<(val)
      if val.is_a? Array
        val.each do |f|
          self << f
        end
      else
        # if it's already indented, don't bother indenting further
        unless val =~ /\A#{@indent_string}/
          indent = @indent_string * @indent_level

          @contents << val.gsub(/^/, indent)
        else
          @contents << val
        end

        # it already has a newline, don't add another
        @contents << "\n" unless val =~ /\n$/
      end
    end
  end
end

# we need to add this so sorting hash keys works properly
class Symbol #:nodoc:
  def <=> (other)
    self.to_s <=> other.to_s
  end
end

class Array #:nodoc:
  include Plist::Emit
end

class Hash #:nodoc:
  include Plist::Emit
end

# === Load a plist file
# This is the main point of the library:
#
#   r = Plist::parse_xml( filename_or_xml )
module Plist
# Note that I don't use these two elements much:
#
#  + Date elements are returned as DateTime objects.
#  + Data elements are implemented as Tempfiles
#
# Plist::parse_xml will blow up if it encounters a data element.
# If you encounter such an error, or if you have a Date element which
# can't be parsed into a Time object, please send your plist file to
# plist@hexane.org so that I can implement the proper support.
  def Plist::parse_xml( filename_or_xml )
    listener = Listener.new
    #parser = REXML::Parsers::StreamParser.new(File.new(filename), listener)
    parser = StreamParser.new(filename_or_xml, listener)
    parser.parse
    listener.result
  end

  class Listener
    #include REXML::StreamListener

    attr_accessor :result, :open

    def initialize
      @result = nil
      @open   = Array.new
    end


    def tag_start(name, attributes)
      @open.push PTag::mappings[name].new
    end

    def text( contents )
      @open.last.text = contents if @open.last
    end

    def tag_end(name)
      last = @open.pop
      if @open.empty?
        @result = last.to_ruby
      else
        @open.last.children.push last
      end
    end
  end

  class StreamParser
    def initialize( plist_data_or_file, listener )
      if plist_data_or_file.respond_to? :read
        @xml = plist_data_or_file.read
      elsif File.exists? plist_data_or_file
        @xml = File.read( plist_data_or_file )
      else
        @xml = plist_data_or_file
      end

      @listener = listener
    end

    TEXT       = /([^<]+)/
    XMLDECL_PATTERN = /<\?xml\s+(.*?)\?>*/um
    DOCTYPE_PATTERN = /\s*<!DOCTYPE\s+(.*?)(\[|>)/um
    COMMENT_START = /\A<!--/u
    COMMENT_END = /.*?-->/um


    def parse
      plist_tags = PTag::mappings.keys.join('|')
      start_tag  = /<(#{plist_tags})([^>]*)>/i
      end_tag    = /<\/(#{plist_tags})[^>]*>/i

      require 'strscan'

      @scanner = StringScanner.new( @xml )
      until @scanner.eos?
        if @scanner.scan(COMMENT_START)
          @scanner.scan(COMMENT_END)
        elsif @scanner.scan(XMLDECL_PATTERN)
        elsif @scanner.scan(DOCTYPE_PATTERN)
        elsif @scanner.scan(start_tag)
          @listener.tag_start(@scanner[1], nil)
          if (@scanner[2] =~ /\/$/)
            @listener.tag_end(@scanner[1])
          end
        elsif @scanner.scan(TEXT)
          @listener.text(@scanner[1])
        elsif @scanner.scan(end_tag)
          @listener.tag_end(@scanner[1])
        else
          raise "Unimplemented element"
        end
      end
    end
  end

  class PTag
    @@mappings = { }
    def PTag::mappings
      @@mappings
    end

    def PTag::inherited( sub_class )
      key = sub_class.to_s.downcase
      key.gsub!(/^plist::/, '' )
      key.gsub!(/^p/, '')  unless key == "plist"

      @@mappings[key] = sub_class
    end

    attr_accessor :text, :children
    def initialize
      @children = Array.new
    end

    def to_ruby
      raise "Unimplemented: " + self.class.to_s + "#to_ruby on #{self.inspect}"
    end
  end

  class PList < PTag
    def to_ruby
      children.first.to_ruby if children.first
    end
  end

  class PDict < PTag
    def to_ruby
      dict = Hash.new
      key = nil

      children.each do |c|
        if key.nil?
          key = c.to_ruby
        else
          dict[key] = c.to_ruby
          key = nil
        end
      end

      dict
    end
  end

  class PKey < PTag
    def to_ruby
      CGI::unescapeHTML(text || '')
    end
  end

  class PString < PTag
    def to_ruby
      CGI::unescapeHTML(text || '')
    end
  end

  class PArray < PTag
    def to_ruby
      children.collect do |c|
        c.to_ruby
      end
    end
  end

  class PInteger < PTag
    def to_ruby
      text.to_i
    end
  end

  class PTrue < PTag
    def to_ruby
      true
    end
  end

  class PFalse < PTag
    def to_ruby
      false
    end
  end

  class PReal < PTag
    def to_ruby
      text.to_f
    end
  end

  require 'date'
  class PDate < PTag
    def to_ruby
      DateTime.parse(text)
    end
  end

  require 'base64'
  class PData < PTag
    def to_ruby
      data = Base64.decode64(text.gsub(/\s+/, ''))

      begin
        return Marshal.load(data)
      rescue Exception => e
        io = StringIO.new
        io.write data
        io.rewind
        return io
      end
    end
  end
end


module Plist
  VERSION = '3.1.0'
end

class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

class Utils
  # escape text for use in an AppleScript string
  def e_as(str)
  	str.to_s.gsub(/(?=["\\])/, '\\')
  end
  # use Growl to display messages
  # checks for existence of growlnotify
  def growl_notify(message,sticky = false)
    flags = sticky ? '-s ' : ''
    if File.exists? "/usr/local/bin/growlnotify"
      app = File.exists?('/Applications/Tags.app') ? "Tags.app" : "Finder.app"
      %x{/usr/local/bin/growlnotify -a "#{app}" #{flags}-m "#{message}"}
    end
  end
  # calls growl_notify and outputs to STDOUT if $conf['debug'] is true
  def debug_msg(message,sticky = true)
    if $conf['debug']
      growl_notify(message,sticky)
      STDOUT.puts message
    end
  end
  # if script is called with -r [DAYS] paramater, change the last_checked timestamp
  def reset_last_check(days)
    reset_time = (Time.now - (60 * 60 * 24 * days.to_i)).strftime('%Y-%m-%dT%H:%M:%SZ')
    %x{defaults write com.brettterpstra.PinboardTagger lastcheck #{reset_time}}
    debug_msg("Reset last check to #{reset_time}")
  end
end

class Pinboard
  attr_accessor :user, :pass, :existing_bookmarks, :new_bookmarks
  def initialize
    # Make storage directory if needed
    FileUtils.mkdir_p($conf['db_location'],:mode => 0755) unless File.exists? $conf['db_location']
    unless $conf['pdf_tag'] == false || $conf['pdf_tag'] == 'false'
      # create PDF directory if needed
      FileUtils.mkdir_p($conf['pdf_location'],:mode => 0755) unless File.exists? $conf['pdf_location']
    end
    # load existing bookmarks database
    @existing_bookmarks = self.read_bookmarks
  end
  # Store a Marshal dump of a hash
  def store obj = @existing_bookmarks, file_name = $conf['db_location']+'/bookmarks.stash', options={:gzip => $conf['gzip_db'] }
    marshal_dump = Marshal.dump(obj)
    file = File.new(file_name,'w')
    file = Zlib::GzipWriter.new(file) unless options[:gzip] == false
    file.write marshal_dump
    file.close
    return obj
  end
  # Load the Marshal dump to a hash
  def load file_name
    begin
      file = Zlib::GzipReader.open(file_name)
    rescue Zlib::GzipFile::Error
      file = File.open(file_name, 'r')
    ensure
      obj = Marshal.load file.read
      file.close
      return obj
    end
  end
  # Set up credentials for Pinboard.in
  def set_auth(user,pass)
    @user = user
    @pass = pass
  end

  def new_bookmarks
     return self.unique_bookmarks
  end

  def existing_bookmarks
    @existing_bookmarks
  end
  # compares local last_check timestamp (stored in `defaults`) to last update stamp from Pinboard
  def needs_update?
    latest = get_xml('/v1/posts/update')
    latest_update = latest.elements['update'].attributes['time']
    latest_time = Time.parse(latest_update)
    unless %x{defaults domains|grep 'com.brettterpstra.PinboardTagger'} == ''
      last_check = %x{defaults read com.brettterpstra.PinboardTagger lastcheck}
      last_time = Time.parse(last_check)
      return latest_time > last_time
    else
      %x{defaults write com.brettterpstra.PinboardTagger lastcheck '2011-04-02T19:37:24Z'}
      return true
    end
  end
  # retrieves the XML output from the Pinboard API
  def get_xml(api_call)
    xml = ''
    http = Net::HTTP.new('api.pinboard.in', 443)
    http.use_ssl = true
    http.start do |http|
    	request = Net::HTTP::Get.new(api_call)
    	request.basic_auth @user,@pass
    	response = http.request(request)
    	response.value
    	xml = response.body
    end
    return REXML::Document.new(xml)
  end
  # converts Pinboard API output to an array of URLs
  def bookmarks_to_array(doc)
    bookmarks = []
    doc.elements.each('posts/post') do |ele|
      post = {}
      ele.attributes.each {|key,val|
        post[key] = val;
      }
      bookmarks.push(post)
    end
    return bookmarks
  end
  # compares bookmark array to existing bookmarks to find new urls
  def unique_bookmarks
      bookmarks = self.bookmarks_to_array(self.get_xml('/v1/posts/all'))
      unless @existing_bookmarks.nil?
        old_hrefs = @existing_bookmarks.map { |x| x['href'] }
        bookmarks.reject! { |s| old_hrefs.include? s['href'] }
      end
      return bookmarks
  end
  # wrapper for load
  def read_bookmarks
    # if the file exists, read it
    if File.exists? $conf['db_location']+'/bookmarks.stash'
      return self.load $conf['db_location']+'/bookmarks.stash'
    else # new database
      return []
    end
  end
end

pb = Pinboard.new
util = Utils.new

pb.set_auth($conf['user'], $conf['password'])
new_bookmarks = pb.new_bookmarks
if ARGV[0] == '-r'
  if ARGV[1] =~ /^\d+$/
    util.reset_last_check(ARGV[1])
  elsif ARGV[1].nil?
    util.reset_last_check(1)
  else
    STDOUT.puts "Invalid reset argument."
    STDOUT.puts "Use '-r [NUMBER OF DAYS]'."
  end
  exit
end
update = pb.needs_update?
if update
  message = "Found #{new_bookmarks.count} unindexed bookmarks"
  message += ". Exiting." if new_bookmarks.count == 0
  util.debug_msg(message,false)
else
  util.debug_msg("Pinboard update timestamp is older than local. Exiting.",false)
end
exit if new_bookmarks.count == 0 || !update
counter = 0
if $conf['update_tags_db']
  tags_db = File.join("#{ENV['HOME']}/Library/Application Support/Tags/Bookmarks.plist")
  File.copy(tags_db,tags_db+'.bak')
  plist = Plist::parse_xml(tags_db)
end
new_bookmarks.each {|bookmark|
  break if counter > 499 # cap the process at 500 bookmarks, resume later
  url = bookmark['href']
  title = bookmark['description']
  cleantitle = title.gsub(/[^A-Za-z0-9 '"_\.\-]+/i, '-').gsub(/^\./,'').strip
  unless File.exists?($conf['target']+'/'+cleantitle+'.webloc')
    comment = bookmark['extended'].strip
    tags = bookmark['tag'].split(' ')
    tags.push($conf['always_tag']) if $conf['always_tag'] && !$conf['always_tag'] != ''
    tags_app_tags = tags.join('","')
    om_tags = tags.join(' ')
    dateformat = "%m-%d-%Y %I:%M%p"
    dateformat = "%d-%m-%Y %I:%M%p" if $conf['dateformat'] && $conf['dateformat'] =~ /uk/i
    date = Time.parse(bookmark['time']).strftime(dateformat)
    util.debug_msg("Grabbing #{title}, tagging with \"#{tags_app_tags}\"",false)
    tagscommand = $conf['tag_method'] == 1 ? %Q{tell application "Tags" to apply tags {"#{tags_app_tags}"} to files} : "return"
    begin
      bookmark['local_path'] = %x{osascript <<-APPLESCRIPT
         tell application "Finder"
          if not (exists alias (("#{$conf['target']}" & "#{util.e_as cleantitle}" as string) & ".webloc")) then
            set webloc to make new internet location file at (POSIX file "#{$conf['target']}") to "#{util.e_as url}" with properties {name:"#{util.e_as cleantitle}",creation date:(AppleScript's date "#{date}"),comment:"#{util.e_as comment}"}
            if #{$conf['tag_method']} > 0 then
              if #{$conf['tag_method']} = 1 then
                #{tagscommand} {POSIX path of (webloc as string)}
              else if #{$conf['tag_method']} = 2 and exists (POSIX file "/usr/local/bin/openmeta") then
                do shell script "/usr/local/bin/openmeta -p '" & POSIX path of (webloc as string) & "' -a #{om_tags}"
              end if
            end if
            if "#{$conf['create_thumbs']}" = "true" and exists (POSIX file "/usr/local/bin/setWeblocThumb") then
              do shell script "/usr/local/bin/setWeblocThumb " & quoted form of (POSIX path of (webloc as string))
            end if
            if {"#{tags_app_tags}"} contains "#{$conf['pdf_tag']}" and "#{$conf['pdf_tag']}" is not "false" then
            	tell application "Paparazzi!"
            		launch hidden
            		set minsize to {1024, 768}
            		capture "#{url}" min size minsize
            		repeat while busy
            			-- To wait until the page is loaded.
            		end repeat
            		save as PDF in POSIX path of "#{$conf['pdf_location']}/#{util.e_as cleantitle}.pdf"
            		quit
            	end tell
            	if #{$conf['tag_method']} > 0 then
                if #{$conf['tag_method']} = 1 then
                  #{tagscommand} {(POSIX path of "#{$conf['pdf_location']}/#{util.e_as cleantitle}.pdf")}
                else if #{$conf['tag_method']} = 2 and exists (POSIX file "/usr/local/bin/openmeta") then
                  do shell script "/usr/local/bin/openmeta -p '" & (POSIX path of "#{$conf['pdf_location']}/#{util.e_as cleantitle}.pdf") & "' -a #{om_tags}"
                end if
              end if
            end if
            return POSIX path of (webloc as string)
          end if
         end tell
         return POSIX path of (alias (("#{$conf['target']}" & "#{util.e_as cleantitle}" as string) & ".webloc"))
    APPLESCRIPT }.strip
      unless bookmark['local_path'] == '' || bookmark['local_path'] == 'AppleScript'
        pb.existing_bookmarks.push(bookmark)
        plist[url] = {"title"=>title, "tags"=>tags, "filename"=>cleantitle+'.webloc'} if $conf['update_tags_db'] && !plist.nil?
        counter += 1
      end
    end  
  else
    util.debug_msg("File exists: "+cleantitle,false)
    bookmark['local_path'] = $conf['target']+'/'+cleantitle+'.webloc'
    pb.existing_bookmarks.push(bookmark)
  end
  
  File.open(tags_db, 'w'){ |io| io << plist.to_plist } if $conf['update_tags_db'] && !plist.nil?
  pb.store
}
latest = pb.get_xml('/v1/posts/update')
latest_update = latest.elements['update'].attributes['time']
%x{defaults write com.brettterpstra.PinboardTagger lastcheck #{latest_update}}
util.growl_notify("Added #{counter} new bookmarks", false) if counter > 0