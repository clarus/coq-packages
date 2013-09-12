# Exports Coq's contribs to Egg packages.
$usage = <<EOF
Usage: to export the Coq's contribs to Egg packages:
    ruby contrib_to_egg.rb path/to/contribs/ path/where/to/export/
EOF

require 'open-uri'
require 'digest/md5'
require 'json'
require 'fileutils'

class Package
  attr_reader :path, :name, :description
  
  def initialize(path)
    @path = path
    @name = File.basename(@path)
    
    def describe(content)
      h = {}
      id = nil
      for line in content.each_line do
        if /([^:]*):\s*(.*)/ =~ line then
          id = $1
          h[id] = $2
        else
          h[id] = h[id] + line
        end
      end
      h
    end
    description_file = File.read(File.join(@path, "description"))
    begin
      @description = describe(description_file)
    rescue ArgumentError
      @description = describe(description_file.force_encoding("ISO-8859-1").encode("utf-8", replace: nil))
    end
  end
  
  def to_s
    @name
  end
  
  def egg
    h = {}
    h["egg-version"] = 1
    h["info"] = @description["Title"] if @description["Title"]
    h["authors"] = [@description["Author"]] if @description["Author"]
    h["homepage"] = @description["Url"] if @description["Url"]
    h["licenses"] = [{"name" => @description["License"]}] if @description["License"]
    h["tags"] = @description["Keywords"].split(/\s*,\s*/) if @description["Keywords"]
    h["maintainer"] = "dev@clarus.me"
    h["build"] = [
      "make",
      "\"sudo\" make \"install\"" ]
    h["url"] = "http://coq.inria.fr/pylons/contribs/files/#{@name}/trunk/#{@name}.tar.gz"
    file = open(h["url"])
    h["checksum"] = Digest::MD5.hexdigest(file.read)
    file.close
    JSON.generate(h, :indent => "  ", :space => " ", :array_nl => "\n", :object_nl => "\n")
  end
end

if ARGV.size == 2 then
  packages = Dir.glob(File.join(ARGV[0], "*", "*")).select {|path| File.directory?(path) && File.exists?(File.join(path, "description")) }
  packages = packages.map {|path| Package.new(path) }
  FileUtils.mkdir_p(ARGV[1])
  for package in packages do
    puts "Processing \"#{package.name}\" ..."
    File.open(File.join(ARGV[1], "#{package.name}.1.0.json"), "w") {|f| f << package.egg }
  end
  puts "#{packages.size} packages successfully converted!"
else
  puts $usage
end
