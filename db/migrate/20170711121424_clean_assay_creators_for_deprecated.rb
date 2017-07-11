class CleanAssayCreatorsForDeprecated < ActiveRecord::Migration
  def up
    execute "DELETE FROM assets_creators WHERE asset_type='DeprecatedSpecimen';"
    execute "DELETE FROM assets_creators WHERE asset_type='DeprecatedSample';"
    execute "DELETE FROM assets_creators WHERE asset_type='DeprecatedTreatment';"
  end

  def down
    #no reversible
  end
end
