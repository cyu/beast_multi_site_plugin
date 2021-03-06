class SitesController < ApplicationController
  
  alias :authorized? :admin?

  before_filter :login_required
  before_filter :find_or_initialize_site, :except => :index

  def index
    respond_to do |format|
      format.html do
        @sites = Site.paginate :page => params[:page], :per_page => 50, :order => "name",
            :conditions => build_site_search_conditions
      end
      format.xml do
        @sites = site_search
        render :xml => @sites.to_xml
      end
    end
  end

  def create
    respond_to do |format|
      format.html do
        @site.attributes = params[:site]
        @site.save!
        flash[:notice] = "Site created"[]
        redirect_to :action => 'index'
      end
    end
  end

  def update
    @site.update_attributes!(params[:site])
    respond_to do |format|
      format.html { redirect_to sites_path }
      format.xml  { head 200 }
    end
  end
  
  def destroy
    @site.destroy
    respond_to do |format|
      format.html { redirect_to sites_path }
      format.xml  { head 200 }
    end
  end
  
  protected
  
    def find_or_initialize_site
      @site = params[:id] ? Site.find(params[:id]) : Site.new
    end
    
    def build_site_search_conditions
      Site.build_search_conditions(params[:q])
    end
    
    def site_search
      Site.search(params[:q], :limit => 25)
    end
end
