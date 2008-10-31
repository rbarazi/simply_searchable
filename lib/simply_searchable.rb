module SpinBits
  module SimplySearchable
    
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
      # 		created_at:datetime
      # 		updated_at:datetime
      # 
      # For integer and datetime like id, created_at and updated_at, 
      # named_scope methods will expect a number and uses equality check to match.
      #
      # For string and text attributes like title and body, 
      # named_scope methods will expect a text and wil match using '%string%'
      def simply_searchable(options = {})
        class_inheritable_accessor :attrs
        self.attrs = self.columns.collect{|c| [c.name, c.type]}
        self.attrs.each do |attribute|
          case attribute[1]
          when :text, :string then 
            named_scope "where_#{attribute[0]}".to_sym, lambda {|value| { :conditions => ["#{attribute[0]} like ?", "%#{value}%"] }}          
          else  
            named_scope "where_#{attribute[0]}".to_sym, lambda {|value| { :conditions => ["#{attribute[0]} = ?", value] }}          
          end
        end
      end
      
      # Return records that matches the passed params, for example:
      # 
      # Post.list(:title => 'abc', :created_at => Date.today)
      # 
      # Will return the posts that contain 'abc' in their title and created today.
      def list(options)
        listings = self
        self.column_names.each do |column_name|
          listings = listings.send("where_#{column_name}".to_sym, options[column_name.to_sym]) unless options[column_name.to_sym].blank?
        end
        return listings.paginate(:page => options[:page])
      end
    end # ClassMethods
  end # SimplySearchable
end # SpinBits