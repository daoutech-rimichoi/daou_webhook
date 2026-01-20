# frozen_string_literal: true

class CreateGitHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :git_histories, if_not_exists: true do |t|
      t.references :issue, type: :integer, null: true, foreign_key: {to_table: :issues}, index: true
      t.references :user, type: :integer, null: true, foreign_key: {to_table: :users}, index: true
      t.text :notes
      t.datetime :created_on

      t.timestamps
    end

    unless index_exists?(:git_histories, :created_on)
      add_index :git_histories, :created_on
    end
  end
end
