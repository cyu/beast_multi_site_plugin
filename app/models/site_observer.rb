class SiteObserver < ActiveRecord::Observer
  def after_save(site)
    ActionController::Routing::RouteSet.clear_site_ids
  end
end
