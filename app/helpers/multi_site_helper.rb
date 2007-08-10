module MultiSiteHelper
  def site_forums
    Forum.find(:all, :order => 'position', :conditions => ['site_id = ?', params[:site_id]])
  end
end