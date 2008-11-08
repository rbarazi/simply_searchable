module RidaAlBarazi #:nodoc:   
  module SimplySearchable #:nodoc:
    
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end
    
    module ClassMethods
      # Defines named_scope methods for all attributes as following:
      # 
      # 	Post
      # 		id:integer
      # 		title:string
      # 		body:text
      #     category_id:integer
      # 		created_at:datetime
      # 		updated_at:datetime
      # 
      # For integer and datetime like id, created_at and updated_at, 
      # named_scope methods will expect a number and uses equality check to match.
      #
      # For string and text attributes like title and body, 
      # named_scope methods will expect a text and wil match using '%string%'
      #
      # By default SimplySearchable uses will_paginate
      # to disable will_paginate just pass: :will_paginate => false
      #
      #   class Post < ActiveRecord::Base
      #     simply_searchable :will_paginate => false
      #   end
      #
      #   class Post < ActiveRecord::Base
      #     simply_searchable :per_page => 20
      #   end
      #
      def simply_searchable(options = {})
        options.reverse_merge!(:per_page => 30, :with_pagination => true)
        class_inheritable_accessor :attrs, :with_pagination, :per_page, :associations
        self.with_pagination = options[:with_pagination]
        self.per_page = options[:per_page]
        self.attrs = self.columns.collect{|c| [c.name, c.type]}
        self.attrs.each do |attribute|
          case attribute[1]
          when :text, :string then 
            named_scope "where_#{attribute[0]}".to_sym, lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} like ?", "%#{value}%"] }}   
          else  
            named_scope "where_#{attribute[0]}".to_sym, 
              lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} in (?)", [*value]] }}          
          end
        end
        self.associations = self.reflections.collect{|key,value| [key, value.macro]}
        self.associations.each do |association|
          case association[1]
          when :has_many, :has_one, :has_and_belong_to_many then 
            named_scope "where_#{association[0].to_s}".to_sym, 
              lambda {|value| { :include => association[0], :conditions => ["#{association[0].to_s.tableize}.id in (?)", [*value]] }}          
          when :belongs_to then  
            named_scope "where_#{association[0]}".to_sym, 
              lambda {|value| { :conditions => ["#{self.table_name}.#{association[0]}_id in (?)", [*value]] }}          
          end
        end
      end
      
      # Return records that matches the passed params, for example:
      # 
      # Post.list(:title => 'abc', :created_at => Date.today)
      # 
      # Will return the posts that contain 'abc' in their title and created today.
      def list(options={})
        listings = self
        options.each_pair do |key, value|
          if !value.blank? and (self.column_names.include?key.to_s or self.reflections.keys.include?key.to_sym)
            listings = listings.send("where_#{key.to_s}".to_sym, value) 
          end
        end
        return Post.with_pagination ? listings.paginate(:page => options[:page], :per_page => options[:per_page]) : listings.all
      end
    end # ClassMethods
  end # SimplySearchable
end # RidaAlBarazi