module Beast
  module Plugins

    class MultiSite < Beast::Plugin
      author 'Calvin Yu - codeeg.com'
      version '0001'
      homepage 'http://blog.codeeg.com'
      notes 'MultiSite support for Beast'

      route :resources, 'sites'

      [ 'controllers', 'helpers', 'models' ].each do |dir|
        path = File.join(plugin_path, 'app', dir)
        Dependencies.load_paths << File.expand_path(path) if File.exist?(path)
      end
      
      def initialize
        super
        ApplicationController.class_eval do
          prepend_view_path File.join(MultiSite::plugin_path, 'app', 'views')
          protected
            def site_admin?(user=nil)
              return false if user.nil? && !logged_in?
              (user || current_user).site_admin?(params[:site_id])
            end
            
            def site
              @site ||= Site.find(params[:site_id])
            end
            helper_method :site_admin?, :site
        end
        ApplicationController.send :helper, :multi_site
        
        User.send :include, UserExtension
        
        ForumsController.class_eval do
          include MultiSiteSupport
          set_scope :forum, :index

          def create_with_site_id
            params[:forum][:site_id] = params[:site_id]
            create_without_site_id
          end
          alias_method_chain :create, :site_id
        end
        
        PostsController.class_eval do
          include MultiSiteSupport
          set_scope :post, :index, :search
        end
        
        UsersController.class_eval do
          protected
            def admin_with_site_admin
              if params[:user] && params[:user][:admin] && !current_user.admin?
                params[:user][:admin] = @user.admin? ? '1' : '0'
              end

              if params[:site_admin] == '1'
                @user.admining_sites << site unless @user.site_admin?(site) 
              else
                @user.admining_sites.delete(site) if @user.site_admin?(site)
              end
              admin_without_site_admin
            end
            alias_method_chain :admin, :site_admin
          
            def authorized_with_site_admin?
              return true if authorized_without_site_admin?
              %w(admin).include?(action_name) && site_admin?
            end
            alias_method_chain :authorized?, :site_admin
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
              @site_ids ||= Site.find(:all).inject({}) {|h, site| h[site.key] = site.id; h}
              @site_ids[key]
            end
        end # RouteSet monkey patch
      end

      module UserExtension
        def self.included(target)
          target.has_and_belongs_to_many :admining_sites, :class_name => 'Site',
              :join_table => :sites_administrators, :foreign_key => 'user_id',
              :association_foreign_key => 'site_id'
        end
        
        def site_admin?(site)
          site = site.id if site.is_a? Site
          admining_site_ids.include? site
        end
      end

      module MultiSiteSupport
        def self.included(target)
          target.extend(ClassMethods)
        end
        
        module ClassMethods
          def set_scope(klazz, *actions)
            actions.each do |action|
              define_method "#{action}_with_site_id".to_sym do
                klazz.to_s.classify.constantize.send :with_scope,
                    :find => { :conditions => ["site_id = ?", params[:site_id]] } do
                  send "#{action}_without_site_id"
                end
              end
              alias_method_chain action, :site_id
            end
          end
        end # ClassMethods module
      end # MultiSiteSupport module

      class Schema < ActiveRecord::Migration
    
        def self.install
          create_table :sites do |t|
            t.column :key, :string
            t.column :name, :string
          end
          add_index :sites, :key, :unique => true
          
          create_table :sites_administrators, :id => false do |t|
            t.column :user_id, :integer
            t.column :site_id, :integer
          end
          add_index :sites_administrators, :user_id
          
          add_column :forums, :site_id, :string
          
          Site.create :key => 'default', :name => 'Default Site'
          Forum.update_all "site_id = 1"
        end
      
        def self.uninstall
          drop_table :sites
          remove_index :sites, :key

          drop_table :sites_administrators
          remove_index :sites_administrators, :user_id

          remove_column :forums, :site_id
        end
      end # end Schema class

    end # end MultiSite class

  end
end
