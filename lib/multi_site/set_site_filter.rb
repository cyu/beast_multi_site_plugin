module MultiSite
  class SetSiteFilter
    def initialize(param_name)
      @param_name = param_name
    end

    def before(controller)
      controller.params[@param_name][:site_id] = controller.params[:site_id]; true
    end

    def after(controller)
    end
  end
end