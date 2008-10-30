module SpinBits
  module SimplySearchable
    
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end
    
    module ClassMethods
      def simply_searchable(options = {})
        class_inheritable_accessor :attrs
        self.attrs = self.columns.collect{|c| [c.name, c.type]}
        self.attrs.each do |attribute|
          named_scope "where_#{attribute[0]}".to_sym, lambda {|value| { :conditions => ["#{attribute[0]} = ?", value] }}          
        end
      end
      
      def list(options)
        self.attrs.each do |attribute|
          listings = (listings || self).send("where_#{attribute[0]}".to_sym, options[:attribute[0].to_sym]) unless options[:attribute[0].to_sym].blank?
        end
        return (listings || self).paginate(:page => options[:page])
      end
    end # ClassMethods
  end # SimplySearchable
end # SpinBits