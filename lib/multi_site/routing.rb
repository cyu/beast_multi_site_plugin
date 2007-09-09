module MultiSite
  module Routing
    def self.initialize
     
      ActionController::Routing::RouteSet.class_eval do
        def recognize(request)
          site, path = extract_site_data(request.path)
          
          params = recognize_path(path, extract_request_environment(request))
          params[:site_key] = site[:key]
          params[:site_id] = site[:id]
          
          request.path_parameters = params.with_indifferent_access
          "#{params[:controller].camelize}Controller".constantize
        end
        
        def self.clear_site_ids
          @@site_ids = nil
        end
        
        protected
          unless method_defined? :generate_with_site_key
            def generate_with_site_key(options, recall = {}, method=:generate)
              site_key = options[:site_key] ? options.delete(:site_key) : recall[:site_key]
              path = generate_without_site_key(options, recall, method)
              site_key == 'default' ? path : "/#{site_key}#{path}"
            end
            alias_method_chain :generate, :site_key
          end
      
          def extract_site_data(path)
            translated_path = path[1..-1] # strip leading '/'
            site_key, translated_path = translated_path.split('/', 2)
            site_id = site_id_for site_key
            
            if site_id
              [{:key => site_key, :id => site_id}, "/#{translated_path}"]
            else
              [{:key => 'default', :id => 1}, path]
            end
          end
          
          def site_id_for(key)
            @@site_ids ||= Site.find(:all).inject({}) {|h, site| h[site.key] = site.id; h}
            @@site_ids[key]
          end
      end # end RouteSet monkey patch
      
    end # end initialize method
  end
end
