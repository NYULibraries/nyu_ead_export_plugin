class EADModel < ASpaceExport::ExportModel
  model_for :ead

  include ASpaceExport::ArchivalObjectDescriptionHelpers
  include ASpaceExport::LazyChildEnumerations

  def addresslines
    agent = self.agent_representation
    return [] unless agent && agent.agent_contacts[0]

    contact = agent.agent_contacts[0]

    data = []
    data << contact['name']
    (1..3).each do |i|
      data << contact["address_#{i}"]
    end

    line = ""
    line += %w(city region).map{|k| contact[k] }.compact.join(', ')
    line += " #{contact['post_code']}"
    line.strip!

    data <<  line unless line.empty?
    data << contact['telephones'][0]['number']
    data << contact['email']


    data.compact!

    data
  end

end
