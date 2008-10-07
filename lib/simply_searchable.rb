module SpinBits
  module SimplySearchable
    
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end
    
    module ClassMethods
      def simply_searchable(options = {})
        options[:fields]      ||= []
        options[:find_method] ||= "find"
        options[:with_pagination] ||= Hash.new
        class_inheritable_accessor :fields, :order, :find_method, :with_pagination
        self.find_method     = options[:find_method]
        self.fields          = options[:fields]
        self.order           = options[:order]
        self.with_pagination = options[:with_pagination]
        include SearchMethods
      end
      
      module SearchMethods      
        def textsearch
          class_name = self.class.to_s.chomp("Controller").singularize.constantize
          instance_name = class_name.to_s.downcase.pluralize
          @query = params[:query]
          ids = class_name.find_by_contents(@query).collect(&:id).join(', ')
          conditions = "id in (#{ids})" unless ids.blank?
          unless conditions.nil?
            eval("@#{instance_name} = class_name.#{self.find_method}(:all, :conditions => '#{conditions}', :order => self.order)") 
          else
            eval("@#{instance_name} = Array.new")
          end
          # load_shared_variables if [Video, Company, Job].include?(class_name)
          render :action => "search"
        end
        
        # POST /objects;search
        # POST /objects.xml;search
        def search
          # Get the model class name from the controller class name
          class_name = self.class.to_s.chomp("Controller").singularize.constantize
          instance_name = class_name.to_s.downcase.pluralize
          
          conditions_array = []
          has_manies = []
          text_fields_conditions = []
          
          search_keys = self.fields << "query"
          # Let's filter the params to have only the specified fields
          fields_params = params.reject{|k,v| (!search_keys.include?(k) || (v.blank?))}
          fields_params.each_pair do |key, value|
            # If the key ends with _id, it is a belongs_to association
            if key.ends_with?("_id")
              conditions_array << "#{key} in (#{Array(value).join(', ')})" unless value.blank?
            elsif key.ends_with?("_id_tree")
              ids = []
              Array(value).each do |sub_value|
                ids << eval("#{key.gsub('_id_tree','').camelize}.find(#{sub_value}).self_and_children_ids.join(', ')")
              end
              conditions_array << "#{key.gsub("_tree",'')} in (#{ids.join(',')})" unless ids.blank?
            #if the key ends with _from then we'll be looking for values greater than the param value
            elsif key.ends_with?("_from")
              conditions_array << "#{key.gsub('_from','')} >= #{value}"
            #if the key ends with _to then we'll be looking for values lesser than the param value
            elsif key.ends_with?("_to")
              conditions_array << "#{key.gsub('_to','')} <= #{value}"
            # If we can singularize the key that means it's plural, therefore a has_many association
            elsif key.singularize != key 
              conditions_array << "#{key}.id in (#{Array(value).join(', ')})" unless value.blank?
              has_manies << key
            # If the key is 'query' then we have to include a subquery  
            elsif key == 'query'
              conditions_array << "#{instance_name}.id in (#{class_name.find_by_contents(value).collect(&:id).join(', ')})"  unless value.empty?
            # If not has_many nor belongs_to nor query then it's an text field
            elsif value.is_a?Array
              conditions_array << "#{key} in ('#{value.join("','")}')"
            # If none of the above then it's an equal to field
            else 
              conditions_array << "#{key} = '#{value}'"
            end
          end
          conditions = conditions_array.join(" AND ")
          conditions_hash = Hash.new
          unless conditions.blank?
            conditions_hash[:conditions] = conditions
            conditions_hash[:order]      = self.order unless self.order.blank? 
            conditions_hash[:include]    = has_manies unless has_manies.blank?
            unless self.with_pagination.blank?
              conditions_hash[:per_page] = self.with_pagination[:per_page]
              conditions_hash[:page]     = params[:page]
            end
            if self.find_method == "find"
              eval("@#{instance_name} = class_name.#{self.find_method} :all, conditions_hash")
            else
              eval("@#{instance_name} = class_name.#{self.find_method} conditions_hash")
            end
          else
            eval("@#{instance_name} = []") # If there are no conditions that means there is no results
          end
          respond_to do |format|
            format.html { load_shared_variables if defined?(load_shared_variables)}
            format.xml  { render :xml => eval("@#{instance_name}.to_xml") }
            format.rss {
              @properties.slice!(25..@properties.size) if @properties.size > 25
              render :action => 'rss.rxml', :layout => false
            }
            format.js   {
               render :update do |page|
                  page[:search_results].replace_html :partial => 'search_results',
                                                     :locals  => { instance_name.to_sym => eval("@#{instance_name}")}
                  page[:rss_link].replace_html :partial => 'rss_link'
                  page.visual_effect :highlight, 'search_results'
               end
            }
          end
        end
      end # SearchMethods
    end # ClassMethods
  end # SimplySearchable
end # SpinBits