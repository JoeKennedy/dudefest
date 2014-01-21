class Article < ActiveRecord::Base
  include ModelConfig

  before_validation :determine_status

  belongs_to :column, inverse_of: :articles, counter_cache: true
  belongs_to :author, class_name: 'User', counter_cache: true
  belongs_to :editor, class_name: 'User'
  belongs_to :movie, inverse_of: :review

  validates_associated :column
  validates_associated :author
  validates_associated :editor, allow_blank: true
  validates :column, presence: true
  validates :title, presence: true, uniqueness: true, length: { in: 10..70 }
  validates :body, presence: true, uniqueness: true, length: { in: 300..10000 }

  rails_admin do
    object_label_method :title
    navigation_label 'Articles'
    list do
      sort_by 'status, date, created_at'
      include_fields :date, :column, :title, :author, :editor, :status
      configure :date do
        strftime_format '%Y-%m-%d'
      end
    end

    edit do
      field :column do
        associated_collection_scope do
          Proc.new { |scope|
            scope = scope.where.not(column: Column.movie.column)
          }
        end
      end
      include_fields :column, :title do
        visible do
          bindings[:object].class == Article && bindings[:object].movie.nil?
        end
        read_only do
          bindings[:object].movie.present?
        end
      end
      field :image do
        visible do
          bindings[:object].class == Movie || bindings[:object].movie.present?
        end
      end
      field :body, :ck_editor
      field :byline, :wysihtml5 do
        bootstrap_wysihtml5_config_options emphasis: false, lists: false,
                                           image: false, :'font-styles' => false
      end
      field :finalized do
        visible do
          bindings[:object].class == Article && bindings[:object].finalizable?
        end
      end
      field :published do
        visible do
          bindings[:object].class == Article && bindings[:object].finalized?
        end
      end
    end

    show do
      include_fields :column, :title, :author, :status, :body
      configure :body do
        pretty_value do
          value.html_safe
        end
      end
    end
  end

  public
    def status?(base_status)
      base_status.to_s == self.status
    end

    def finalizable?
      if self.editor.present? 
        self.editor_or_admin? && !self.finalized?
      else
        false
      end
    end

    def display_date
      self.date.strftime('%B %d, %Y')
    end

    def type
      self.column.short_name.upcase
    end

    def display_image
      self.image || self.column.default_image
    end

    def display_byline
      self.byline.blank? ? self.author.byline : self.byline
    end

    def author_and_date
      'By ' + @article.author.name + ' on ' + @article.display_date
    end

    def editor_or_admin?
      self.editor == User.current || User.current.role?(:admin)
    end

    def public?
      tz = 'Eastern Time (US & Canada)'
      self.published? && self.date <= DateTime.now.in_time_zone(tz).to_date
    end

    def self.public
      self.order(date: :desc).select { |article| article.public? }
    end

  private
    def determine_status
      if self.new_record?
        self.finalized = self.published = false
        self.status = '1 - Created'
        self.author = User.current
        self.editor = set_editor
      elsif self.published?
        self.status = '5 - Published'
        if self.published_at.nil?
          self.published_at = Time.now
          if self.class.select(:date).count > 0
            self.date = self.class.maximum(:date) + 1.day
          else
            self.date = self.class.start_date
          end
        end
      elsif self.finalized?
        self.status = '4 - Finalized'
        self.finalized_at ||= Time.now
      elsif self.editor == User.current || self.class.owner == User.current
        self.status = '2 - Edited'
        self.editor ||= User.current
        self.edited_at = Time.now
      elsif self.status?('2 - Edited') && self.author == User.current
        self.status = '3 - Responded'
        self.responded_at = Time.now
      end
    end

    def set_editor
      User.current == self.class.owner ? User.find(5) : self.class.owner
    end

    def is_movie_review?
      self.column.present? && self.column.column == Column.movie
    end
end
