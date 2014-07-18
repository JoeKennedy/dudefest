class ArticleMailer < ActionMailer::Base
  require 'mail'
  default from: '"John Dudefest" <dudes@dudefest.com>'

  def created_email(article)
    @article = article
    mail(to: collect_emails([@article.editor]), 
         subject: 'You got an article to edit, brah!')
  end

  def edited_email(article)
    @article = article
    mail(to: collect_emails([@article.creator]),
         subject: 'You got some edits to respond to, brah!')
  end

  def responded_email(article)
    @article = article
    mail(to: collect_emails([@article.editor]),
         subject: 'You got some responses to your edits, brah!')
  end

  def rejected_email(article)
    @article = article
    emails = collect_emails([@article.editor, @article.creator])
    mail(to: emails, subject: 'An article got rejected, brah!')
  end

  def rewrite_email(article)
    @article = article
    mail(to: collect_emails([@article.creator]),
         subject: 'You got an article to rewrite, brah!')
  end

  def finalized_email(article)
    @article = article
    emails = collect_emails(User.with_role(:reviewer) << @article.creator)
    mail(to: emails, subject: 'Your article was finalized, brah!')
  end

  def reviewed_email(article)
    @article = article
    emails = collect_emails([@article.creator, @article.editor])
    mail(to: emails, subject: 'Your article was reviewed, brah!')
  end

  private
    def collect_emails(users)
      (User.with_role(:admin) | users).map do |user|
        address = Mail::Address.new user.email
        address.display_name = user.name
        address.format
      end.join(',')
    end
end
