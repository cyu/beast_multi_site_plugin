module Beast
  module Plugins

    class MultiSite < Beast::Plugin
      author 'Calvin Yu - codeeg.com'
      version '0003'
      homepage 'http://boardista.com'
      notes 'MultiSite support for Beast'

      route :resources, 'sites'

      %w( controllers helpers models ).each do |dir|
        path = File.expand_path(File.join(plugin_path, 'app', dir))
        if File.exist?(path) && !Dependencies.load_paths.include?(path)
          Dependencies.load_paths << path
        end
      end
      
      def initialize
        super
        SiteObserver.instance
        
        ApplicationController.class_eval do
          prepend_view_path File.join(MultiSite::plugin_path, 'app', 'views')
          protected
            def site_admin?(user=nil)
              return false if user.nil? && !logged_in?
              (user || current_user).site_admin?(params[:site_id])
            end

            def administrable?
              admin? || site_admin?
            end
            
            def site
              @current_site ||= Site.find(params[:site_id])
            end
            helper_method :site_admin?, :site, :administrable?
            helper :multi_site
        end
        
        User.send :include, UserExtension
        Forum.belongs_to :site
        
        ForumsController.class_eval do
          around_filter ::MultiSite::SiteFilter.new(:forum), :only => :index
          around_filter ::MultiSite::SetSiteFilter.new(:forum), :only => :create
          around_filter :set_topic_and_forum_filter, :only => :index
          
          cache_sweeper :site_posts_sweeper, :only => [:create, :update, :destroy]

          protected
            def authorized?
              admin? || (site_admin? && !%w(destroy).include?(action_name))
            end
            
            def set_topic_and_forum_filter
              find_options = {
                  :conditions => ["forums.site_id = ?", params[:site_id]],
                  :include => :forum }

              Topic.send(:with_scope, :find => find_options) do
                Post.send(:with_scope, :find => find_options) { yield }
              end
            end
        end
        
        PostsController.around_filter ::MultiSite::SiteFilter.new(:post), :only => [:index, :search]
        PostsController.cache_sweeper :site_posts_sweeper, :only => [:create, :update, :destroy]
        
        TopicsController.cache_sweeper :site_posts_sweeper, :only => [:create, :update, :destroy]
        
        UsersController.class_eval do
          before_filter :update_site_admin, :only => :admin
          protected
            def update_site_admin
              if params[:user] && params[:user][:admin] && !current_user.admin?
                params[:user][:admin] = @user.admin? ? '1' : '0'
              end

              if params[:site_admin] == '1'
                @user.admining_sites << site unless @user.site_admin?(site) 
              else
                @user.admining_sites.delete(site) if @user.site_admin?(site)
              end
              
              true
            end
          
            def authorized_with_site_admin?
              return true if authorized_without_site_admin?
              %w(admin).include?(action_name) && site_admin?
            end
            alias_method_chain :authorized?, :site_admin
        end
        
        ActionController::Routing::RouteSet.send :include, ::MultiSite::Routing::RouteSetExtensions
      end # end initialize method
      
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
