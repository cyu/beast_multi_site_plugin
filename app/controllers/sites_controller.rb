class SitesController < ApplicationController
  
  alias :authorized? :admin?

  before_filter :login_required

  def index
    respond_to do |format|
      format.html do
        @sites = Site.paginate :page => params[:page], :per_page => 50, :order => "name", :conditions => Site.build_search_conditions(params[:q])
        @site_count = Site.count
      end
      format.xml do
        @sites = Site.search(params[:q], :limit => 25)
        render :xml => @sites.to_xml
      end
    end
  end

  def create
    respond_to do |format|
      format.html do
        @site = Site.create!(params[:site])
        flash[:notice] = "Site created"[]
        redirect_to :action => 'index'
      end
    end
  end

end
