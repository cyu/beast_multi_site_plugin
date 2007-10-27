module MultiSite
  module ActionControllerBaseExt
    def self.included(base)
      base.alias_method_chain :url_for, :domain unless base.method_defined?(:url_for_without_domain)
    end
    
    def url_for_with_domain(options)
      if set_url_host_option?(options)
        host = []
        host << options[:site_key] unless options[:site_key] == 'default'
        
        request_host = request.host.split('.')
        host << (request_host.length == 1 ? request_host : request_host[-2..-1])
        
        options = options.merge(:host => host.flatten.join('.'), :port => request.port)
      end

      url_for_without_domain(options)
    end
    
    protected

      def set_url_host_option?(options)
        MultiSite::RouteSetExt.use_subdomain? && options[:site_key] && params[:site_key] != options[:site_key]
      end
  end
end