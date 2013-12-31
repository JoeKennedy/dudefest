class Position < ActiveRecord::Base
  include ModelConfig, ItemReview, DailyItem

  validates :position, presence: true, length: { in: 3..32 }, uniqueness: true
  validates :description, presence: true, length: { in: 100..500 }, 
                          uniqueness: true
  validates :image, presence: true, uniqueness: true
  validates_formatting_of :image, using: :url
  validates :image, format: { with: /\.(png|jpg|jpeg|)\z/,
                              message: 'must be .png, .jpg, or .jpeg' }

  auto_html_for :image do
    html_escape
    image
  end

  rails_admin do
    object_label_method :position
    navigation_label 'Daily Items'
    list do
      sort_by :date, :created_at
      include_fields :date, :position, :creator, :reviewed
      configure :date do
        strftime_format '%Y-%m-%d'
      end
    end

    edit do
      include_fields :position, :description, :image, :reviewed do
        read_only do
          bindings[:object].is_read_only?
        end
      end
      include_fields :notes 
      configure :reviewed do
        visible do
          bindings[:object].reviewable?
        end
      end
    end

    show do
      include_fields :position, :description
      field :image_html
      field :creator
    end
  end
end