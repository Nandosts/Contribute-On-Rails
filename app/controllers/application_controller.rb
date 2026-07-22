class ApplicationController < ActionController::Base
  include Pagy::Method

  allow_browser versions: :modern

  before_action :set_locale, :set_starter_mode

  helper_method :starter_mode?

  private

  def set_locale
    if params[:locale].present? && I18n.available_locales.map(&:to_s).include?(params[:locale])
      session[:locale] = params[:locale]
    end

    I18n.locale = session[:locale] || extract_locale_from_accept_language_header || I18n.default_locale
  end

  def extract_locale_from_accept_language_header
    if params[:locale].present? && I18n.available_locales.map(&:to_s).include?(params[:locale])
      return params[:locale]
    end

    accept_language = request.env["HTTP_ACCEPT_LANGUAGE"]
    return nil if accept_language.blank?

    browser_locales = accept_language.scan(/[a-z]{2}(?:-[A-Z]{2})?/)
    browser_locales.each do |locale|
      return locale if I18n.available_locales.map(&:to_s).include?(locale)

      base_locale = locale.split("-").first
      matched = I18n.available_locales.map(&:to_s).find { |al| al.split("-").first == base_locale }
      return matched if matched
    end

    nil
  end

  def set_starter_mode
    stored_preference = cookies.signed[:starter_mode]
    @starter_mode = if params.key?(:starter_mode)
      ActiveModel::Type::Boolean.new.cast(params[:starter_mode])
    elsif stored_preference.nil?
      true
    else
      ActiveModel::Type::Boolean.new.cast(stored_preference)
    end

    return unless params.key?(:starter_mode)

    cookies.permanent.signed[:starter_mode] = {
      value: @starter_mode,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def starter_mode?
    @starter_mode
  end

  def effective_issue_labels
    labels = Array(params[:labels]).reject(&:blank?)
    starter_labels = Issue::STARTER_LABELS.map(&:downcase).sort

    return [] if !starter_mode? && labels.map(&:downcase).uniq.sort == starter_labels

    labels
  end
end
