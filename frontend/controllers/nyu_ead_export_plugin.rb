class NyuEadExportPluginController < ApplicationController

  skip_before_action :unauthorised_access

  def index
    version = "2.8.0"
    url = "https://github.com/NYULibraries/nyu_ead_export_plugin/releases/tag/v2.7.1"
    maintainer = "Donald Mennerich don.mennerich@nyu.edu"
  end

end
