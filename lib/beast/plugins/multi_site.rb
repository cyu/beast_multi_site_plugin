module Beast
  module Plugins

    class MultiSite < Beast::Plugin
      author 'Calvin Yu - codeeg.com'
      version '0001'
      homepage 'http://blog.codeeg.com'
      notes 'MultiSite support for Beast'

      [ 'controllers', 'helpers', 'models' ].each do |dir|
        path = File.join(plugin_path, 'app', dir)
        Dependencies.load_paths << File.expand_path(path) if File.exist?(path)
      end
      
      def initialize
        super
        
        ApplicationController.class_eval do
          protected
            def current_user=(value)
              if @current_user = value
                site_session[:user_id] = @current_user.id 
                # this is used while we're logged in to know which threads are new, etc
                site_session[:last_active] = @current_user.last_seen_at
                site_session[:topics] = site_session[:forums] = {}
                update_last_seen_at
              end
            end
            
            def current_user
              @current_user ||= ((current_user_id && User.find_by_id(current_user_id)) || 0)
            end
            
            def current_user_id
              site_session[:user_id]
            end
            
            def site_session
              session[:sites] ||= {}
              session[:sites][params[:site_key]] ||= {}
            end
        end
        
        ForumsController.class_eval do
          include MultiSiteSupport
          set_scope :forum, :index
        end
        
        PostsController.class_eval do
          include MultiSiteSupport
          set_scope :post, :index
        end
        
        UsersController.class_eval do
          include MultiSiteSupport
          set_scope :user, :index
        end
        
        # limit uniqueness validations for a user to a site.
        ActiveRecord::Validations::ClassMethods.module_eval do
          unless method_defined? :validates_uniqueness_of_with_site_scoped
            def validates_uniqueness_of_with_site_scoped(*attr_names)
              p attr_names
              #attr_names << {:scope => :site_id} if [ :display_name ].find { |v| attr_names.include? v }
              validates_uniqueness_of_without_site_scoped(*attr_names)
            end
            alias_method_chain :validates_uniqueness_of, :site_scoped
          end
        end
        
        ActionController::Routing::RouteSet.class_eval do
          def recognize(request)
            site, path = extract_site_data(request.path)
            
            params = recognize_path(path, extract_request_environment(request))
            params[:site_key] = site[:key]
            params[:site_id] = site[:id]
            
            request.path_parameters = params.with_indifferent_access
            "#{params[:controller].camelize}Controller".constantize
          end
          
          protected
            unless method_defined? :generate_with_site_key
              def generate_with_site_key(options, recall = {}, method=:generate)
                site_key = recall[:site_key]
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
              @site_ids ||= Site.find(:all).inject({}) {|h, site| h[site.key] = site.id; h}
              @site_ids[key]
            end
        end # RouteSet monkey patch
      end

      module MultiSiteSupport
        def self.included(target)
          target.extend(ClassMethods)
        end
        
        module ClassMethods
          def set_scope(klazz, action)
            define_method "#{action}_with_site_id".to_sym do
              klazz.to_s.classify.constantize.send :with_scope,
                  :find => { :conditions => ["site_id = ?", params[:site_id]] } do
                send "#{action}_without_site_id"
              end
            end
            alias_method_chain action, :site_id
          end
        end # ClassMethods module
      end # SiteScopeLock module       
      
      module UserExtension
        def self.included(target)
          #target.extend(ClassMethods)
          target.alias_method_chain :validates_uniqueness_of, :site_scoped
        end

        #module ClassMethods
          def validates_uniqueness_of_with_site_scoped(*attr_names)
            p attr_names
            #attr_names << {:scope => :site_id} if [ :display_name ].find { |v| attr_names.include? v }
            validates_uniqueness_of_without_site_scoped(*attr_names)
          end
        #end
      end # UserExtension module

      class Schema < ActiveRecord::Migration
    
        def self.install
          create_table :sites do |t|
            t.column :key, :string
            t.column :name, :string
          end

          add_column :forums, :site_id, :string
          add_column :users, :site_id, :string
          
          Site.create :key => 'default', :name => 'Default Site'
          Forum.update_all "site_id = 1"
          User.update_all "site_id = 1"
        end
      
        def self.uninstall
          drop_table :sites

          remove_column :forums, :site_id
          remove_column :users, :site_id
        end
      end # end Schema class

    end # end MultiSite class

  end
end
