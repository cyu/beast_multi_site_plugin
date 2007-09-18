class SiteObserver < ActiveRecord::Observer
  def after_save(site)
    MultiSite::Routing.clear_site_ids
  end
end
