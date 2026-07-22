module ApplicationHelper
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
