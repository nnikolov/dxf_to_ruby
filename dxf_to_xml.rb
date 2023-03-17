#
# dxf_to_xml
#
# v. 20230317
#
# Nick Nikolov
# nrnickolov@yahoo.com
# March 17, 2023
#
# The purspose of this script is to convert a DXF file into an XML file.
# The XML file can easily be viewed in Firefox and helps to inspect
# and debug DXF files.
#
# Use the following command to run on the command line:
#
# ruby dxf_to_xml.rb input_filename.dxf optional_ouput_filename.xml
#
# If optional_output_filename.xml is not specified,
# the output file will have the same filename as the input file
# with an xml extensionm
#

module ActiveDxf
  class DxfToXml

    attr_accessor :input_file
    attr_accessor :output_file
    attr_accessor :file_contents
    attr_accessor :pairs
    attr_accessor :xml

    def initialize(*args)
      @debug = false
      @xml_stack = []
      self.pairs = []

      # convert the arguments to a hash
      options = args.reduce({}, :merge)
      
      # check if a input_file is given
      load_file(options[:input_file]) if options.key?(:input_file)
                               
      # check if a input_file is given
      self.output_file = options[:output_file] if options.key?(:output_file)
    end

    def load_file(filename = nil)
      self.input_file = filename unless filename.nil?
      self.file_contents = File.read(input_file)
      parse_contents
      export_to_xml
    end

    # Checks if filename is nil and sets it to the input filename with
    # xml extension if so
    def validated_output_file
      return output_file unless output_file.nil?
      new_extension = "xml"
      input_file.sub(/\.dxf$/, ".#{new_extension}")
    end

    def export_to_xml(filename = nil)
      self.output_file = filename unless filename.nil?
      of = validated_output_file
      File.write(of, self.xml.to_s)
    end

    # Starts the parsing process
    # Pairs up each odd numbered line with the following even numbered line to create a key, val pair
    # Starts the xml conversion
    def parse_contents
      tmp = file_contents
      # Convert return with new line to new line, so we always work with new line only
      tmp = tmp.gsub(/\r\n/) {|match| "\n"}
      # Create an array splitting on new line
      tmp = tmp.split("\n")
      # truncate the last line if line number is odd
      tmp.pop() unless tmp.size.even?
      # create an array containing hashes of key, value pairs
      tmp.each_slice(2) {|key, value| self.pairs << { key.to_s.strip => value.strip } }
      @tmp_pairs = pairs
      convert_to_xml
    end

    # Adds the start and end xml tags
    # Calls each_pair
    def convert_to_xml
      self.xml = "<xml>"
      each_pair
      self.xml += "\r\n</xml>"
    end

    # Maps the closing tag to the opening tag
    def translate_stack_val(val)
      return "SECTION" if val == "ENDSEC"
      return "TABLE" if val == "ENDTAB"
      return "BLOCK" if val == "ENDBLK"
    end

    # Recursive method that loops through key, val pairs and adds them to the xml string
    # It opens a new tag and calls itself if an open tag is encountered
    # It closes the tag before exiting.
    # This method is way too long and packs too much logic.
    # Needs to be refactored.
    def each_pair
      while true
        pair = @tmp_pairs.shift
        return if pair.nil?
        pair.each do |key, val|
          if key == "0" and val[0..2] == "END"
            translated_stack_val = translate_stack_val(val)
            stack_val = @xml_stack.pop
            if stack_val == translated_stack_val # Exit
              self.xml += "\r\n<key_#{key}>#{val}</key_#{key}>"
              self.xml += "\r\n<stack>#{@xml_stack.to_s}</stack>" if @debug
              return
            else # Exit and force another exit until the value matches the stack value
              @tmp_pairs.unshift(pair)
              self.xml += "\r\n<stack>#{@xml_stack.to_s}</stack>" if @debug
              return
            end
          end
          # Add a special case for entities.
          # Without this, as soon as the entity type changes,
          # the remainding entities become children of the
          # last instance of the first entity type.
          # For example if you have circle, circle, line, line, arc, arc
          # the lines and arcs would become children of the
          # last circle
          if key == "2" and val == "ENTITIES"
            @xml_stack << val
            self.xml += "\r\n<#{val.downcase}>"
            self.xml += "\r\n<key_#{key}>#{val}</key_#{key}>"
            each_pair # Recursive call
            self.xml += "\r\n</#{val.downcase}>"
            return
          end
          # If key = 0 and value is uppercase
          # Start a new nested level unless the previous value is the same
          # In that case close out the current level and start a new one at the same depth
          if key == "0" and val == val.upcase and val[0..2] != "END"
            if @xml_stack[-1] == val or @xml_stack.size > 2
              @xml_stack.pop
              @tmp_pairs.unshift(pair) # Put the pair back, so it gets read again and return
              return
            end
            @xml_stack << val
            self.xml += "\r\n<#{val.downcase}>"
            self.xml += "\r\n<key_#{key}>#{val}</key_#{key}>"
            each_pair # Recursive call
            self.xml += "\r\n</#{val.downcase}>"
          else
            self.xml += "\r\n<key_#{key}>#{val}</key_#{key}>"
          end
        end
      end
    end

  end
end

input_file = ARGV[0]
output_file = ARGV[1]

dxf = ActiveDxf::DxfToXml.new
dxf.output_file = output_file
dxf.input_file = input_file
dxf.load_file
