class AddFirstReplyToIssue < ActiveRecord::Migration[5.1]
  def change
    add_column :issues, :first_reply, :boolean, default: false
  end
end
