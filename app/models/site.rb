class Site < ActiveRecord::Base
  has_and_belongs_to_many :site_admins, :class_name => 'User', :join_table => :sites_administrators,
      :foreign_key => 'site_id', :association_foreign_key => 'user_id'
  has_many :forums
  
  validates_presence_of :key, :name
  validates_exclusion_of :key, :message => "Invalid site key", :in => (%w(
      activate forums logged_exceptions login logout posts session settings signup sites users
      images javascripts stylesheets system ) +
      (const_defined?(:MULTI_SITE_EXCLUDED_KEYS) ? MULTI_SITE_EXCLUDED_KEYS : []))
  validates_format_of :key, :with => /\A[a-z0-9_-]+\Z/i
  validates_uniqueness_of :key

  def self.search(query, options = {})
    with_scope :find => { :conditions => build_search_conditions(query) } do
      find :all, options
    end
  end

  def self.build_search_conditions(query)
    query && ['LOWER(name) LIKE :q', {:q => "%#{query}%"}]
  end

end