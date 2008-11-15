require 'test/unit'
 
require 'rubygems'
require 'active_record'
 
$:.unshift File.dirname(__FILE__) + '/../lib'
require File.dirname(__FILE__) + '/../init'
 
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")
 
# AR keeps printing annoying schema statements
$stdout = StringIO.new
 
def setup_db
  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 1) do
    create_table :posts do |t|
      t.column :id, :integer
      t.column :title, :string
      t.column :body, :text
      t.column :category_id, :integer
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end
end
 
def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end
 
setup_db
class Post < ActiveRecord::Base
  belongs_to :category
  simply_searchable
end
class Category < ActiveRecord::Base
  has_many :posts
end
teardown_db

class SimplySearchableTest < Test::Unit::TestCase
  
  def setup
    setup_db
    @post = Post.create(:title => 'Some title', :body => 'Some text here', :category_id => 1)
  end
 
  def teardown
    teardown_db
  end
 
  def test_creation_of_named_scope_methods_for_attributes
    assert Post.methods.include?('where_title')
    assert Post.methods.include?('where_body')
  end
  
  def test_creation_of_named_scope_methods_for_associations
    assert Post.methods.include?('where_category')
  end
  
  def test_creation_of_list
    assert Post.methods.include?('list')
  end
end