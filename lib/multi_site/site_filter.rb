module MultiSite
  class SiteFilter
    def initialize(scoped_class)
      @scoped_class = scoped_class
    end

    def filter(controller, &block)
      scoped_class.send :with_scope,
          :find => { :conditions => ["site_id = ?", controller.params[:site_id]] } do
        block.call
      end
    end

    protected
    
      def scoped_class
        @scoped_class.to_s.classify.constantize
      end
  end
end