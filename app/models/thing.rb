class Thing < ActiveRecord::Base
  include EasternTime, ModelConfig, ItemReview, DailyItem
  mount_uploader :image, ImageUploader
  process_in_background :image

  before_validation :sanitize

  belongs_to :thing_category, inverse_of: :things

  validates :thing, presence: true, length: { in: 3..26 }, uniqueness: true
  # No longer a thing
  #validates :image_old, presence: true, uniqueness: true
  #validates_formatting_of :image_old, using: :url
  #validates :image_old, format: { with: /\.(png|jpg|jpeg|)\z/,
  #                            message: 'must be .png, .jpg, or .jpeg' }
  validates :description, presence: true, length: { in: 150..500}, 
                          uniqueness: true
  validates :thing_category, presence: true

  auto_html_for :image_old do
    html_escape
    image
  end

  rails_admin do
    object_label_method :thing
    navigation_label 'Daily Items'
    configure :image, :jcrop
    configure :thing_category do
      label 'Category'
      column_width 120
    end

    list do
      sort_by 'date, reviewed, created_at'
      include_fields :date, :thing_category, :thing, :creator, :reviewed
      configure :date do
        strftime_format '%Y-%m-%d'
        column_width 75
      end
      configure :reviewed do
        column_width 75
      end
    end

    edit do
      include_fields :thing_category, :thing, :description, :image,
                     :published, :reviewed do
        read_only do
          bindings[:object].is_read_only?
        end
      end
      configure :description do
        help ('Required. Between 150 and 500.<br>'\
              'That gives you a lot of room to wiggle. The generally agreed '\
              'upon form is to make this a definition.<br>Start your '\
              'description with the name of the thing because there '\
              'will be a picture separating it from the entry’s title.<br>'\
              'Make sure that if you’re using a first person pronoun '\
              'use "we" instead of "I" because Dudefest.com speaks '\
              'with one voice.<br>Make sure you have a punchline in mind '\
              'when you start your entry.').html_safe
      end
      field :image do
        jcrop_options aspectRatio: 400.0/300.0
        fit_image true
      end
      field :remote_image_url do
        label 'Or Image URL'
        read_only do
          bindings[:object].is_read_only?
        end
      end
      field :image_old do
        read_only true
      end
      configure :published do
        visible do
          bindings[:object].reviewed? 
        end
      end
      configure :reviewed do
        visible do
          bindings[:object].reviewable? && !bindings[:object].reviewed?
        end
      end
      include_fields :notes
    end

    show do
      include_fields :thing_category, :thing
      field :image_old_html
      include_fields :description, :creator
    end
  end
  
  public
    def category
      self.thing_category.category
    end

    def display_image
      self.image.present? ? self.image_url(:display).to_s : self.image_old
    end

  private
    def sanitize
      Sanitize.clean!(self.thing)
      Sanitize.clean!(self.description)
      Sanitize.clean!(self.image_old)
    end
end
