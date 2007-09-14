class SitePostsSweeper < ActionController::Caching::Sweeper
  observe Post
  
  def after_save(post)
    site_key = post.forum.site.key
    FileUtils.rm_rf File.join(RAILS_ROOT, 'public', site_key, 'forums', post.forum_id.to_s, 'posts.rss')
    FileUtils.rm_rf File.join(RAILS_ROOT, 'public', site_key, 'forums', post.forum_id.to_s, 'topics', "#{post.topic_id}.rss")
    FileUtils.rm_rf File.join(RAILS_ROOT, 'public', site_key, 'users')
    FileUtils.rm_rf File.join(RAILS_ROOT, 'public', site_key, 'posts.rss')
  end
  
  alias_method :after_destroy, :after_save
end