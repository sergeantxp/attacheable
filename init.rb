class ActiveRecord::Base
  #
  # In model write has_attachment (conflicts with acts_as_attachment) with options:
  # 
  # :thumbnails => list of thumbnails, i.e.  {:medium => "120x", :large => "800x600"}
  # :croppable_thumbnails => list of thumbnails, which must be cropped to center, i.e.:  [:large, :preview]
  # :path_prefix => path, where to store photos, i.e.: "public/system/photos"
  #
  # After this, add to routes:
  #  map.assets 'system/photos/*path_info', :controller => "photos", :action => "show"
  # and add to PhotosController:
  # def show
  #  render :text => Photo.data_by_path_info(params[:path_info])
  # end
  # This will enable creation on demand
  # 
  def self.has_attachment(options = {})
    #@attachment_options = options
    define_method :attachment_options do
      options
    end
    
    options[:thumbnails] ||= {}
    options[:croppable_thumbnails] ||= []
  
    include(Attacheable)
  end
  
  def self.validates_as_attachment
  end
end
