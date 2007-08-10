class Site < ActiveRecord::Base
  has_and_belongs_to_many :site_admins, :class_name => 'User', :join_table => :sites_administrators,
      :foreign_key => 'site_id', :association_foreign_key => 'user_id'
end