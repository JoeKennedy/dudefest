class Tip < ActiveRecord::Base
  include EasternTime, ModelConfig, ItemReview, DailyItem

  before_validation :sanitize

  has_paper_trail

  validates :tip, presence: true, uniqueness: true, length: { in: 10..200 }

  rails_admin do
    label 'Just the Tip'
    navigation_label 'Daily Items'
    list do
      sort_by :date, :created_at
      include_fields :date, :tip, :creator, :reviewed
      configure :date do
        strftime_format '%Y-%m-%d'
        column_width 75
      end
      configure :tip do
        label 'Just the Tip'
      end
      configure :reviewed do
        column_width 75
      end
    end

    edit do
      include_fields :tip, :reviewed, :published do
        read_only do
          bindings[:object].is_read_only?
        end
      end
      include_fields :notes
      configure :tip do
        label 'Put your tip in'
        help 'Required. Between 10 and 200 characters. '\
             'Keep the tips short and sweet. A piece of advice or a '\
             'question leading off makes them very strong, followed '\
             'by no more than two sentences to '\
             'explain how to achieve the desired outcome.'
      end
      configure :reviewed do
        visible do
          bindings[:object].reviewable? && !bindings[:object].reviewed?
        end
      end
      configure :published do
        visible do
          bindings[:object].reviewed?
        end
      end
    end
  end

  private
    def sanitize
      Sanitize.clean!(self.tip)
    end

    def tip_help
      'Required. Between 10 and 200 characters. '\
      'I think just the tip of the day is a pretty strong category. I '\
      'really like keeping the tips short and sweet. A piece of advice or a '\
      'question leading off makes them very strong, followed by no more '\
      'than two sentences to explain how to achieve the desired outcome.'
    end
end
