class EADModel < ASpaceExport::ExportModel
  model_for :ead

  include ASpaceExport::ArchivalObjectDescriptionHelpers
  include ASpaceExport::LazyChildEnumerations

  def addresslines
    agent = self.agent_representation
    return [] unless agent && agent.agent_contacts[0]

    contact = agent.agent_contacts[0]

    data = []

    data << contact['name'] if contact['name']
    (1..3).each do |i|
      if contact["address_#{i}"]
        data << contact["address_#{i}"]
      end
    end

    line = ""

    line += %w(city region).map{|k| contact[k] if contact[k] }.compact.join(', ')
    line += " #{contact['post_code']}" if contact['post_code']
    line.strip!

    data <<  line unless line.empty?
    data << contact['telephones'][0]['number'] if contact['telephones'].size > 0
    data << contact['email'] if contact['email']

    data.compact!

    data

  end

end
