module ApplicationHelper
  SITE_NAME = "Contribute on Rails".freeze

  def page_title
    title = content_for(:title).presence
    title ? "#{title} | #{SITE_NAME}" : SITE_NAME
  end

  def page_description
    content_for(:description).presence || t("app.description")
  end

  def canonical_url(locale: I18n.locale)
    query = { locale: locale }
    query[:page] = params[:page] if params[:page].present?
    url_for(only_path: false, **query)
  end

  def starter_mode_toggle_params(filter_params)
    toggle_params = filter_params.to_h.stringify_keys.except("starter_mode", "page")
    toggle_params["starter_mode"] = !starter_mode?
    toggle_params["labels"] = if starter_mode?
      Array(toggle_params["labels"]).reject do |label|
        Issue::STARTER_LABELS.any? { |starter_label| starter_label.casecmp?(label) }
      end
    else
      Issue::STARTER_LABELS
    end
    toggle_params
  end
end
