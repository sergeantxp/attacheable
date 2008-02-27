class ActiveRecord::Base
  def self.has_attachment(options = {})
    @attachment_options = options
    
    instance_eval <<-EOF
    def attachment_options
      @attachment_options
    end
    EOF
  
    options[:thumbnails] ||= {}
    options[:croppable_thumbnails] ||= []
  
    class_eval <<-EOF
    def attachment_options
      self.class.attachment_options
    end
    EOF

    include(Attacheable)
  end
end