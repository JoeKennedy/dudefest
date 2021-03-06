module ModelConfig
  extend ActiveSupport::Concern

  included do
    resourcify
  end

  module ClassMethods
    def owner
      model = Model.where(model: self.to_s).first
      model.present? ? model.owner : User.first
    end

    def start_date 
      model = Model.where(model: self.to_s).first
      model.present? ? model.start_date : Date.today
    end
  end
end
