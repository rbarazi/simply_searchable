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
        class_inheritable_accessor :attrs, :with_pagination, :per_page, :associations, :with_tags
        self.with_pagination = options[:with_pagination]
        self.with_tags = options[:with_tags]
        self.per_page = options[:per_page]
        self.attrs = self.columns.collect{|c| [c.name, c.type] unless [*options[:except]].include?(c.name.to_sym)}.compact
        self.attrs.each do |attribute|
          case attribute[1]
          when :text, :string then 
            named_scope "where_#{attribute[0]}_starts_with".to_sym, lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} like ?", "%#{value}%"] }}
          else  
            named_scope "where_#{attribute[0]}".to_sym, 
              lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} in (?)", [*value]] }}          
          end
          # Filtering scopes
          named_scope "where_#{attribute[0]}_starts_with".to_sym, lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} like ?", "#{value}%"] }}   
          named_scope "where_#{attribute[0]}_ends_with".to_sym, lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} like ?", "%#{value}"] }}   
          named_scope "where_#{attribute[0]}_contains".to_sym, lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} like ?", "%#{value}%"] }}   
          named_scope "where_#{attribute[0]}_does_not_contain".to_sym, lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} not like ?", "%#{value}%"] }}   
          named_scope "where_#{attribute[0]}_is_available".to_sym, :conditions => "#{self.table_name}.#{attribute[0]} is not null"
          named_scope "where_#{attribute[0]}_is_not_available".to_sym, :conditions => "#{self.table_name}.#{attribute[0]} is null"
          named_scope "where_#{attribute[0]}_is".to_sym, 
            lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} = ?", value] }}
          named_scope "where_#{attribute[0]}_greater_than".to_sym, 
            lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} > ?", value] }}
          named_scope "where_#{attribute[0]}_lesser_than".to_sym, 
            lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} < ?", value] }}
          named_scope "where_#{attribute[0]}_is_not".to_sym, 
            lambda {|value| { :conditions => ["#{self.table_name}.#{attribute[0]} <> ?", value] }}
        end
        self.associations = self.reflections.collect{|key,value| [key, value.macro]}
        self.associations.each do |association|
          case association[1]
          when :has_many, :has_one, :has_and_belongs_to_many then 
            named_scope "where_#{association[0].to_s}".to_sym, 
              lambda {|value| { :include => association[0], :conditions => ["#{association[0].to_s.tableize}.id in (?)", [*value]] }}          
          when :belongs_to then  
            named_scope "where_#{association[0]}".to_sym, 
              lambda {|value| { :conditions => ["#{self.table_name}.#{association[0]}_id in (?)", [*value]] }}          
          end
        end
        self.attrs = self.attrs.collect(&:first)
        self.attrs += [*options[:include]] if [*options[:include]].any?
      end
      
      # Return records that matches the passed params, for example:
      # 
      # Post.list(:title => 'abc', :created_at => Date.today)
      # 
      # Will return the posts that contain 'abc' in their title and created today.
      def list(options={}, find_options={})
        listings = find_proxy(options)
        return self.with_pagination ? listings.paginate(:page => options[:page], :per_page => options[:per_page]) : listings.scoped(find_options)
      end
      
      def find_proxy(options)
        listings = self.scoped({})
        filters = (options[:filters] || {})
        filters.values.each do |filter|
          if (self.attrs.include?filter[:field].to_s) and !filter[:criteria].blank?
            if filter[:value].blank?
              listings = listings.send("where_#{filter[:field].to_s}_#{filter[:criteria]}".to_sym)
            else 
              listings = listings.send("where_#{filter[:field].to_s}_#{filter[:criteria]}".to_sym, filter[:value]) 
            end
          elsif filter[:field].to_s == 'tags' and self.with_tags
            listings = case filter[:criteria]
            when 'excluding' then listings.find_tagged_with(filter[:value], :exclude => true)
            when 'matching'  then listings.find_tagged_with(filter[:value], :match_all => true)
            else                  listings.find_tagged_with(filter[:value])
            end
          end
        end
        options.each_pair do |key, value|
          if !value.blank? and (self.attrs.include?key.to_s)
            listings = listings.send("where_#{key.to_s}".to_sym, value) 
          end
        end
        return listings
      end
    end # ClassMethods
  end # SimplySearchable
end # RidaAlBarazi