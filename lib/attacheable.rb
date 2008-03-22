class ActiveRecord::Base
  #
  # In model write has_attachment (conflicts with acts_as_attachment) with options:
  # 
  # :thumbnails => list of thumbnails, i.e.  {:medium => "120x", :large => "800x600"}
  # :croppable_thumbnails => list of thumbnails, which must be cropped to center, i.e.:  [:large, :preview]
  # :path_prefix => path, where to store photos, i.e.: "public/system/photos"
  # :replicas => [{:user => "user1", :host => "host1"}], list of hosts, where to clone all loaded originals
  # :autocreate => true/false, whether to autocreate thumbnails on requesting thumbnail
  #
  # After this, add to routes:
  #  map.assets 'system/photos/*path_info', :controller => "photos", :action => "show"
  # and add to PhotosController:
  # def show
  #   photo, data = Photo.data_by_path_info(params[:path_info])
  #   render :text => data, :content_type => photo && photo.content_type
  # end
  # This will enable creation on demand
  #
  # You can also add 
  #  uri "/system/photos/", :handler => Attacheable::PhotoHandler.new("/system/photos"), :in_front => true 
  # to any mongrel scripts for nonblocking image creation
  # 
  # Table for this plugin should have fields:
  #       filename : string
  #   content_type : string  (optional)
  #          width : integer (optional)
  #         heigth : integer (optional)
  #
  #
  def self.has_attachment(options = {})
    class_inheritable_accessor :attachment_options
    self.attachment_options = options
    
    options.with_indifferent_access
    options[:autocreate] ||= false
    options[:thumbnails] ||= {}
    options[:thumbnails].symbolize_keys!.with_indifferent_access
    options[:croppable_thumbnails] ||= []
    options[:croppable_thumbnails] = options[:croppable_thumbnails].map(&:to_sym)
    options[:path_prefix] ||= "public/system/#{table_name}"
    options[:valid_filetypes] ||= %w(jpeg gif png psd)
    include(Attacheable)
  end
  
  def self.validates_as_attachment
    validate :valid_filetype?
  end
end


module Attacheable
  def self.included(base) #:nodoc:
    base.before_update :rename_file
    base.after_save :save_to_storage
    base.after_destroy :remove_files
    base.extend(ClassMethods)
  end

  module ClassMethods

    def regenerate_thumbnails!(thumbnail = nil)
      connection.select_values("select id from #{table_name}").each do |object_id|
        object = find_by_id(object_id)
        if object
          if thumbnail
            FileUtils.rm_f(object.full_filename_without_creation(thumbnail))
          else
            to_remove = Dir["#{File.dirname(object.full_filename_without_creation)}/*"] - [object.full_filename_without_creation]
            FileUtils.rm_f(to_remove)
          end
          #object.full_filename_with_creation(thumbnail)
        end
      end
    end
  
    def data_by_path_info(path_info)
      id1, id2, path = path_info
      return [nil, nil] unless id1 && id2 && path
      object = find(id1.to_i*1000 + id2.to_i)
      if path = object.full_filename_by_path(path)
        return [object, File.read(path)] if File.exists?(path)
      end
      [object, nil]
    end
  end

  def attachment_options
    self.class.attachment_options
  end


  def full_filename(thumbnail = nil)
    attachment_options[:autocreate] ? full_filename_with_creation(thumbnail) : full_filename_without_creation(thumbnail)
  end

  def full_filename_with_creation(thumbnail = nil)
    create_thumbnail_if_required(thumbnail)
  end

  def full_filename_without_creation(thumbnail = nil)
    file_system_path = attachment_options[:path_prefix]
    File.join(RAILS_ROOT, file_system_path, *partitioned_path(thumbnail_name_for(thumbnail)))
  end

  def thumbnail_name_for(thumbnail = nil)
    return filename if thumbnail.blank?
    ext = nil
    basename = filename.gsub /\.\w+$/ do |s|
      ext = s; ''
    end
    "#{basename}_#{thumbnail}#{ext}"
  end


  def base_path
    @base_path ||= File.join(RAILS_ROOT, 'public')
  end
  
  def full_filename_by_path(path)
    ext = nil
    basename = filename.gsub /\.[^\.]+$/ do |s|
      ext = s; ''
    end
    thumbnail = path.gsub(%r(^#{Regexp.escape(basename)}_), '').gsub(%r(#{Regexp.escape(ext)}$), '').to_sym
    return unless attachment_options[:thumbnails][thumbnail]
    full_filename_with_creation(thumbnail)
  end

  # Gets the public path to the file
  # The optional thumbnail argument will output the thumbnail's filename.
  def public_filename(thumbnail = nil)
    full_filename(thumbnail).gsub %r(^#{Regexp.escape(base_path)}), ''
  end

  def public_filename_without_creation(thumbnail = nil)
    full_filename_without_creation(thumbnail).gsub %r(^#{Regexp.escape(base_path)}), ''
  end

  # overrwrite this to do your own app-specific partitioning. 
  # you can thank Jamis Buck for this: http://www.37signals.com/svn/archives2/id_partitioning.php
  def partitioned_path(*args)
    ("%08d" % id).scan(/..../) + args
  end

  def create_thumbnail_if_required(thumbnail)
    thumbnail_path = full_filename_without_creation(thumbnail)
    return thumbnail_path unless thumbnail
    return thumbnail_path if File.exists?(thumbnail_path)
    return unless /image\//.match(content_type)
    if attachment_options[:croppable_thumbnails].include?(thumbnail.to_sym)
      crop_and_thumbnail(thumbnail, thumbnail_path)
    else
      create_thumbnail(thumbnail, thumbnail_path)
    end
    thumbnail_path
  end

  def create_thumbnail(thumbnail, thumbnail_path)
    return nil unless File.exists?(full_filename)
    return nil unless attachment_options[:thumbnails][thumbnail.to_sym]
    `convert -thumbnail #{attachment_options[:thumbnails][thumbnail.to_sym]} "#{full_filename}" "#{thumbnail_path}"`
    thumbnail_path
  end




  def valid_filetype?
    errors.add("uploaded_data", "Неправильный тип файла. Должен быть один из: #{attachment_options[:valid_filetypes].join(", ")}") unless @valid_filetype
  end

  def uploaded_data=(file_data)
    return nil if file_data.nil? || file_data.size == 0 
    self.filename     = file_data.original_filename
    if file_data.is_a?(StringIO)
      file_data.rewind
      @tempfile = Tempfile.new(filename)
      @tempfile.write(file_data.read)
      @tempfile.close
    else
      @tempfile = file_data
    end
    if attachment_options[:valid_filetypes] == :all
      @valid_filetype = true
      @save_new_attachment = true
      self.content_type = file_data.content_type if file_data.respond_to?(:content_type)
    else
      output = `identify "#{@tempfile.path}" 2>/dev/null`
      if output && match_data = / (\w+) (\d+)x(\d+) /.match(output)
        file_type = match_data[1].to_s.downcase
        if attachment_options[:valid_filetypes].include?(file_type)
          @valid_filetype = true
          @save_new_attachment = true
          self.content_type = "image/#{file_type}"
          self.width = match_data[2] if(respond_to?(:width=))
          self.height = match_data[3] if(respond_to?(:height=))
        end
      end
    end
    
  
    unless @valid_filetype
      @save_new_attachment = false
      #File.unlink(@tempfile.path) rescue nil
      @tempfile = nil
      return false
    end
  end

  def image_size
    [width.to_s, height.to_s] * 'x'
  end


  def sanitize_filename(filename)
    returning filename.strip do |name|
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      name.gsub! /^.*(\\|\/)/, ''

      # Finally, replace all non alphanumeric, underscore or periods with underscore
      name.gsub! /[^\w\.\-]/, '_'
    end
  end


  def filename=(value)
    @old_filename = full_filename unless filename.nil? || @old_filename
    write_attribute :filename, sanitize_filename(value)
  end


  def crop_and_thumbnail(thumbnail, thumbnail_path)
    album_x, album_y = attachment_options[:thumbnails][thumbnail.to_sym].split("x").map &:to_i
    scale_x = width.to_f / album_x
    scale_y = height.to_f / album_y
    if scale_x > scale_y
      x, y = (album_x*scale_y).floor, height
      shift_x, shift_y = (width-x)/2, 0
    else
      x, y = width, (album_y*scale_x).floor
      shift_x, shift_y = 0, (height - y)/2
    end
#    FileUtils.cp(full_filename_without_creation, thumbnail_path)
    `convert -crop #{x}x#{y}+#{shift_x}+#{shift_y} "#{full_filename}" "#{thumbnail_path}"`
    `mogrify  -geometry #{album_x}x#{album_y} "#{thumbnail_path}"`
    thumbnail_path
  end

protected
  # Destroys the file.  Called in the after_destroy callback
  def remove_files
    FileUtils.rm_rf(File.dirname(full_filename_without_creation))
  rescue
    logger.info "Exception destroying  #{full_filename.inspect}: [#{$!.class.name}] #{$1.to_s}"
    logger.warn $!.backtrace.collect { |b| " > #{b}" }.join("\n")
  end

  # Renames the given file before saving
  def rename_file
    return unless @old_filename && @old_filename != full_filename
    if @save_new_attachment && File.exists?(@old_filename)
      FileUtils.rm @old_filename
    elsif File.exists?(@old_filename)
      FileUtils.mv @old_filename, full_filename
    end
    @old_filename =  nil
    true
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
