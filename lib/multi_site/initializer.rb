module MultiSite
  module Initializer
    def self.run
      ActiveRecord::Acts::List::ClassMethods.module_eval do
        protected
          def acts_as_list_with_scope(options = {})
            options[:scope] = :site if name == 'Forum'
            acts_as_list_without_scope(options)
          end
          alias_method_chain :acts_as_list, :scope
      end
    end
  end
end