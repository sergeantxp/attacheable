module Attacheable
  module FileNaming
    def full_filename_with_creation(thumbnail = nil) #:nodoc:
      create_thumbnail_if_required(thumbnail) 
    end

    def full_filename_without_creation(thumbnail = nil) #:nodoc:
      file_system_path = attachment_options[:path_prefix]
      File.join(Attacheable.root, file_system_path, *partitioned_path(thumbnail_name_for(thumbnail)))
    end

    def thumbnail_name_for(thumbnail = nil) #:nodoc:
      return filename if thumbnail.blank?
      ext = nil
      basename = filename.gsub /\.\w+$/ do |s|
        ext = s; ''
      end

      if thumbnail.is_a?(String) && thumbnail =~ /\d+[<>]?x\d+[<>]?/i
        "#{basename}_#{thumbnail.hash.abs.to_s}#{ext}"
      else
        "#{basename}_#{thumbnail}#{ext}"
      end
    end

    def public_filename_without_creation(thumbnail = nil)
      full_filename_without_creation(thumbnail).gsub %r(^#{Regexp.escape(base_path)}), ''
    end

    def base_path #:nodoc:
      @base_path ||= File.join(Attacheable.root, 'public')
    end
    
    def attachment_basename
      filename && filename.gsub(/\.[^\.]+$/, '')
    end

    def attachment_extname
      filename && filename.gsub(/^(.*)(\.[^\.]+)$/, '\2')
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
  end
end