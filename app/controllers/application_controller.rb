class ApplicationController < ActionController::Base
  include Pagy::Method

  allow_browser versions: :modern

  before_action :set_locale

  private

  def set_locale
    I18n.locale = extract_locale_from_accept_language_header || I18n.default_locale
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
end
