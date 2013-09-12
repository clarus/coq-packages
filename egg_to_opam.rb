# Export Egg packages to OPAM packages.
$usage = <<EOF
Usage: to export Egg packages to OPAM packages:
    ruby egg_to_opam.rb path/to/eggs/ path/where/to/export/
EOF

require 'json'
require 'json-schema'
require 'stringio'
require 'fileutils'

class Egg
  attr_reader :name, :version
  
  def initialize(file_name, schema)
    if /\A([^.]+)\.(.+)\z/ === File.basename(file_name, ".json") then
      @name = $1
      @version = $2
    else
      raise "The file name \"#{file_name}\" should respect the format \"name.version.json\"."
    end
    
    @egg = JSON.parse(File.read(file_name))
    JSON::Validator.validate!(schema, @egg)
    raise "\"egg-version\" must be 1" unless @egg["egg-version"] == 1
    
    if @egg["dependencies"] then
      @egg["dependencies"] = @egg["dependencies"].to_a.map do |name, contraints|
        if contraints.size == 0 then
          "\"#{name}\""
        else
          "\"#{name}\" { " + contraints.join(" & ") + " }"
        end
      end
    end
  end
  
  def descr
    @egg["info"]
  end
  
  def opam
    s = StringIO.new
    s.puts "opam-version: \"1\""
    s.puts "authors: [\"#{@egg["authors"].join("\" \"")}\"]" if @egg["authors"]
    s.puts "homepage: \"#{@egg["homepage"]}\"" if @egg["homepage"]
    s.puts "license: \"#{@egg["licenses"].map {|l| l["name"]}.join(", ") }\"" if @egg["licenses"] && @egg["licenses"]
    s.puts "tags: [\"#{@egg["tags"].join("\" \"")}\"]" if @egg["tags"]
    s.puts "maintainer: \"#{@egg["maintainer"]}\"" if @egg["maintainer"]
    s.puts "depends: [#{@egg["dependencies"].join(" ")}]" if @egg["dependencies"]
    s.puts "build: [ [#{@egg["build"].join("] [")}] ]" if @egg["build"]
    s.puts "remove: [#{@egg["remove"].join("] [")}]" if @egg["remove"]
    s.string
  end
  
  def url
    s = StringIO.new
    s.puts "archive: \"#{@egg["url"]}\""
    s.puts "checksum: \"#{@egg["checksum"]}\""
    s.string
  end
end

if ARGV.size == 2 then
  schema = File.read("egg_schema.json")
  eggs = Dir.glob(File.join(ARGV[0], "*.json")).map do |file_name|
    Egg.new(file_name, schema)
  end
  for egg in eggs do
    puts "Processing \"#{egg.name} #{egg.version}\" ..."
    path = File.join(ARGV[1], "#{egg.name}.#{egg.version}")
    FileUtils.mkdir_p(path)
    File.open(File.join(path, "descr"), "w") {|f| f << egg.descr}
    File.open(File.join(path, "opam"), "w") {|f| f << egg.opam}
    File.open(File.join(path, "url"), "w") {|f| f << egg.url}
  end
  puts "#{eggs.size} packages successfully exported!"
else
  puts $usage
end
