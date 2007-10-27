class SiteObserver < ActiveRecord::Observer
  def after_save(site)
    MultiSite::RouteSetExt.clear_site_ids
  end
end
