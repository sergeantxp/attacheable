require File.dirname(__FILE__)+"/attacheable/file_naming"
require File.dirname(__FILE__)+"/attacheable/uploading"
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
  
  #
  # Currently it will check valid filetype (unless option valid_filetypes set to :all)
  #
  def self.validates_as_attachment
    validate :valid_filetype?
  end
end


module Attacheable
  include Attacheable::Uploading
  include Attacheable::FileNaming

  def self.included(base) #:nodoc:
    base.before_update :rename_file
    base.after_save :save_to_storage
    base.after_destroy :remove_files
    base.extend(ClassMethods)
  end
  
  
  def self.root
    return RAILS_ROOT if defined?(RAILS_ROOT)
    return Merb.root if defined?(Merb)
    return File.dirname(__FILE__)+"/../.."
  end

  module ClassMethods

    #
    # You can delete all thumbnails or with selected type
    #
    def regenerate_thumbnails!(thumbnail = nil)
      connection.select_values("select id from #{table_name}").each do |object_id|
        object = find_by_id(object_id)
        if object && object.filename
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
  
    #
    # It is designed to read  params[:path_info], or splitted PATH_INFO in mongrel handler
    # It assumes, that path_info is of the following format ["0000", "0001", "file_medium.jpg"]
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

  def attachment_options #:nodoc:
    self.class.attachment_options
  end

  #
  # Returns real path to original file if thumbnail is nil or path with thumbnail part inserted
  # If options[:autocreate] is set to true, this method will autogenerate thumbnail
  #
  def full_filename(thumbnail = nil)
    return "" if filename.blank?
    attachment_options[:autocreate] ? full_filename_with_creation(thumbnail) : full_filename_without_creation(thumbnail)
  end

  def full_filename_by_path(path) #:nodoc:
    return if filename.blank?
    thumbnail = path.gsub(%r((^#{Regexp.escape(attachment_basename)}_)(\w+)(#{Regexp.escape(attachment_extname)})$), '\2')
    return unless thumbnail
    return unless attachment_options[:thumbnails][thumbnail.to_sym]
    full_filename_with_creation(thumbnail.to_sym)
  end

  # Gets the public path to the file, visible to browser
  # The optional thumbnail argument will output the thumbnail's filename.
  # If options[:autocreate] is set to true, this method will autogenerate thumbnail
  def public_filename(thumbnail = nil)
    return "" if filename.blank?
    full_filename(thumbnail).gsub %r(^#{Regexp.escape(base_path)}), ''
  end

  protected

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


  public

  def valid_filetype? #:nodoc:
    errors.add("uploaded_data", "Неправильный тип файла. Должен быть один из: #{attachment_options[:valid_filetypes].join(", ")}") if @save_new_attachment && !@valid_filetype
  end

  # Main method, that accepts uploaded data
  #
  def uploaded_data=(file_data)
    prepare_uploaded_file(file_data)
    file_type = identify_uploaded_file_type
    if accepts_file_type_for_upload?(file_type)
      handle_uploaded_file
    end
  end
  
  def image_size
    [width.to_s, height.to_s] * 'x'
  end

  def filename=(value)
    @old_filename = full_filename unless filename.nil? || @old_filename
    write_attribute :filename, sanitize_filename(value)
  end

  protected


  def crop_and_thumbnail(thumbnail, thumbnail_path)
    if !respond_to?(:width) || !respond_to?(:height)
      file_type, width, height = identify_file_type(full_filename)
    end
    album_x, album_y = attachment_options[:thumbnails][thumbnail.to_sym].split("x").map &:to_i
    scale_x = width.to_f / album_x
    scale_y = height.to_f / album_y
    if scale_x > scale_y
      x, y = (album_x*scale_y).floor, height
      shift_x, shift_y = (width.to_i - x)/2, 0
    else
      x, y = width, (album_y*scale_x).floor
      shift_x, shift_y = 0, (height.to_i - y)/2
    end
#    FileUtils.cp(full_filename_without_creation, thumbnail_path)
    `convert -crop #{x}x#{y}+#{shift_x}+#{shift_y} "#{full_filename}" "#{thumbnail_path}"`
    `mogrify  -geometry #{album_x}x#{album_y} "#{thumbnail_path}"`
    thumbnail_path
  end

  # Destroys the file.  Called in the after_destroy callback
  def remove_files
    return unless filename
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
 
end
