module SpinBits
  module SimplySearchable
    
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end
    
    module ClassMethods
      def simply_searchable(options = {})
        include SearchMethods
      end
      
      def list(options)
        
      end
    end # ClassMethods
  end # SimplySearchable
end # SpinBits