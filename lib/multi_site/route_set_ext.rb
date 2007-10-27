module MultiSite

  module RouteSetExt
    mattr_accessor :use_subdomain
    @@use_subdomain = Object.const_defined?('MULTI_SITE_ROUTING_USE_SUBDOMAIN') ? ::MULTI_SITE_ROUTING_USE_SUBDOMAIN : false
    def self.use_subdomain?
      @@use_subdomain
    end

    def self.clear_site_ids
      @@site_ids = nil
    end
    
    def self.site_id_for(key)
      @@site_ids ||= Site.find(:all).inject({}) {|h, site| h[site.key] = site.id; h}
      @@site_ids[key]
    end
    
    def self.included(base)
      # need this block to work around class reloading
      unless base.method_defined?(:recognize_path_without_site_values)
        base.alias_method_chain :recognize_path, :site_values
        base.alias_method_chain :extract_request_environment, :site_values
        base.alias_method_chain :generate, :site_key
      end
    end

    protected

      def recognize_path_with_site_values(path, environment = {})
        params = if MultiSite::RouteSetExt.use_subdomain? || environment[:site_key] == 'default'
          recognize_path_without_site_values(path, environment)
        else
          pos = path.index('/',1)
          translated_path = pos ? path[pos..-1] : '/'
          recognize_path_without_site_values(translated_path, environment)
        end
        
        params[:site_key] = environment[:site_key]
        params[:site_id] = environment[:site_id]
        params
      end

      def extract_request_environment_with_site_values(request)
        env = extract_request_environment_without_site_values(request)
        
        if MultiSite::RouteSetExt.use_subdomain?
          env.merge(extract_site_values_from_subdomain(request.subdomains.first))
        else
          env.merge(extract_site_values_from_path(request.path))
        end
      end
      
      def extract_site_values_from_path(path)
        translated_path = path[1..-1] # strip leading '/'
        site_key = translated_path.split('/', 2)[0]
        site_id = site_id_for(site_key)
        
        site_id ? {:site_key => site_key, :site_id => site_id} : {:site_key => 'default', :site_id => 1} 
      end
      
      def extract_site_values_from_subdomain(subdomain)
        site_key = (subdomain.blank? || subdomain == 'www') ? 'default' : subdomain
        site_id = site_id_for(site_key)
        
        site_id ? {:site_key => site_key, :site_id => site_id} : {:site_key => 'default', :site_id => 1}
      end
    
      def generate_with_site_key(options, recall = {}, method=:generate)
        site_key = options[:site_key] ? options.delete(:site_key) : recall[:site_key]
        path = generate_without_site_key(options, recall, method)
        (MultiSite::RouteSetExt.use_subdomain? || site_key == 'default') ? path : "/#{site_key}#{path}"
      end
    
      def site_id_for(key)
        MultiSite::RouteSetExt.site_id_for(key)
      end
  end # end RouteSetExt module

end
