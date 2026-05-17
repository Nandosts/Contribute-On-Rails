class NormalizeAndMergeDuplicateLabels < ActiveRecord::Migration[8.1]
  def up
    Label.all.to_a.each do |label|
      next unless Label.exists?(label.id)

      normalized_name = label.name.gsub("-", " ").squish.titleize

      canonical_label = Label.where("LOWER(name) = ?", normalized_name.downcase)
                             .where.not(id: label.id)
                             .first

      if canonical_label
        IssueLabel.where(label_id: label.id).find_each do |il|
          if IssueLabel.exists?(issue_id: il.issue_id, label_id: canonical_label.id)
            il.destroy!
          else
            il.update!(label_id: canonical_label.id)
          end
        end
        label.destroy!
      else
        label.update_columns(name: normalized_name)
      end
    end
  end

  def down
    # Normalization is lossy, so keep as-is.
  end
end
