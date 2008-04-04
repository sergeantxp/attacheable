module Attacheable
  module Uploading
    def prepare_uploaded_file(file_data)
      return prepare_merb_uploaded_file(file_data) if file_data.is_a?(Hash) && file_data["content_type"] && file_data["tempfile"]
      return nil if file_data.nil? || !file_data.respond_to?(:size) || !file_data.respond_to?(:original_filename) ||
        file_data.size == 0 
      self.filename     = file_data.original_filename
      self.size = file_data.size if respond_to?(:size=)
      if file_data.is_a?(StringIO)
        file_data.rewind
        @tempfile = Tempfile.new(filename)
        @tempfile.write(file_data.read)
        @tempfile.close
      else
        @tempfile = file_data
      end
      @save_new_attachment = true
      @valid_filetype = false
    end
    
    def prepare_merb_uploaded_file(file_data)
      return nil if file_data["tempfile"].blank? || file_data["filename"].blank? || file_data["content_type"].blank?
      self.filename = file_data["filename"]
      self.size = file_data["size"] if respond_to?(:size=)
      @tempfile = file_data["tempfile"]
      @save_new_attachment = true
      @valid_filetype = false
    end
    
    def identify_uploaded_file_type
      return unless @tempfile
      file_type, width, height = identify_file_type(@tempfile.path)
      if file_type
        self.width = width if(respond_to?(:width=))
        self.height = height if(respond_to?(:height=))
        self.content_type = "image/#{file_type}"
        file_type
      else
        self.content_type = @tempfile.content_type if @tempfile.respond_to?(:content_type)
      end
    end
    
    def identify_file_type(path)
      return [nil,nil,nil] if path.blank?
      output = `identify "#{path}"`
      if output && match_data = / (\w+) (\d+)x(\d+) /.match(output)
        file_type = match_data[1].to_s.downcase
        width = match_data[2]
        height = match_data[3]
        return [file_type, width, height]
      end
    end
    
    def accepts_file_type_for_upload?(file_type)
      return false unless @tempfile
      return true if attachment_options[:valid_filetypes] == :all
      return true if attachment_options[:valid_filetypes].include?(file_type)
    end
    
    def handle_uploaded_file
      @save_new_attachment = true
      @valid_filetype = true
    end
    
    # Saves the file to the file system
    def save_to_storage
      if @save_new_attachment
        FileUtils.mkdir_p(File.dirname(full_filename))
        FileUtils.cp(@tempfile.path, full_filename)
        File.chmod(0644, full_filename)
        save_to_replicas
      end
      @save_new_attachment = false
      @tempfile = nil
      true
    end

    def save_to_replicas
      attachment_options[:replicas].each do |replica|
        system("ssh #{replica[:user]}@#{replica[:host]} mkdir -p \"#{File.dirname(full_filename)}\"")
        system("scp \"#{full_filename}\" \"#{replica[:user]}@#{replica[:host]}:#{full_filename}\"")
      end if attachment_options[:replicas]
    end
  end
end
