require 'test_helper'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :images do |t|
      t.string :filename
      t.string :content_type
      t.integer :width
      t.integer :height
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Image < ActiveRecord::Base
  has_attachment :thumbnails => {:medium => "120x", :large => "800x600", :preview => "100x100"},
    :croppable_thumbnails => [:preview]
end

class Photo < Image
end

class AttacheableTest < Test::Unit::TestCase
  def setup
    setup_db
  end
  
  def teardown
    teardown_db
  end
  
  def test_image_creation
    
  end
end