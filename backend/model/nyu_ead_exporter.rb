require 'nokogiri'
require 'securerandom'
require 'time'

class EADSerializer < ASpaceExport::Serializer
  serializer_for :ead

  def stream(data)
    return if data.publish === false && !data.include_unpublished?
    @xlink_namespace = "ns2"
    @stream_handler = ASpaceExport::StreamHandler.new
    @fragments = ASpaceExport::RawXMLHandler.new
    @include_unpublished = data.include_unpublished?
    @include_daos = data.include_daos?
    @use_numbered_c_tags = data.use_numbered_c_tags?
    @id_prefix = I18n.t('archival_object.ref_id_export_prefix', :default => 'aspace_')
    doc = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
      begin

        xml.ead(                  'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation' => 'urn:isbn:1-931666-22-9 http://www.loc.gov/ead/ead.xsd',
          "xmlns:#{@xlink_namespace}" => 'http://www.w3.org/1999/xlink') {

            xml.text (
              @stream_handler.buffer { |xml, new_fragments|
                serialize_eadheader(data, xml, new_fragments)
                })

                atts = {:level => data.level, :otherlevel => data.other_level}

                atts.reject! {|k, v| v.nil?}

                xml.archdesc(atts) {



                  xml.did {


                    if (val = data.language)
                      xml.langmaterial { xml.language(:langcode => val) }
                    end

                    if (val = data.repo.name)
                      xml.repository {
                        xml.corpname { sanitize_mixed_content(val, xml, @fragments) }
                      }
                    end

                    if (val = data.title)
                      xml.unittitle  {   sanitize_mixed_content(val, xml, @fragments) }
                    end

                    serialize_origination(data, xml, @fragments)

                    xml.unitid (0..3).map{|i| data.send("id_#{i}")}.compact.join('.')

                    serialize_extents(data, xml, @fragments)

                    serialize_dates(data, xml, @fragments)

                    serialize_did_notes(data, xml, @fragments)

                    #unless data.instances_with_containers.nil?
                    data.instances_with_sub_containers.each do |instance|
                      serialize_container(instance, xml, @fragments)
                    end
                    #end

                    EADSerializer.run_serialize_step(data, xml, @fragments, :did)

                  }# </did>

                  data.digital_objects.each do |dob|
                    serialize_digital_object(dob, xml, @fragments)
                  end

                  serialize_nondid_notes(data, xml, @fragments)

                  serialize_bibliographies(data, xml, @fragments)

                  serialize_indexes(data, xml, @fragments)

                  serialize_controlaccess(data, xml, @fragments)

                  EADSerializer.run_serialize_step(data, xml, @fragments, :archdesc)

                  xml.dsc {

                    data.children_indexes.each do |i|
                      xml.text(
                        @stream_handler.buffer {|xml, new_fragments|
                          serialize_child(data.get_child(i), xml, new_fragments)
                        }
                      )
                    end
                  }
                }
              }

            rescue => e
              xml.text  "ASPACE EXPORT ERROR : YOU HAVE A PROBLEM WITH YOUR EXPORT OF YOUR RESOURCE. THE FOLLOWING INFORMATION MAY HELP:\n
              MESSAGE: #{e.message.inspect}  \n
              TRACE: #{e.backtrace.inspect} \n "
            end



          end
          doc.doc.root.add_namespace nil, 'urn:isbn:1-931666-22-9'

          Enumerator.new do |y|
            @stream_handler.stream_out(doc, @fragments, y)
          end


        end

        def serialize_did_notes(data, xml, fragments)
          data.notes.each do |note|
            next if note["publish"] === false && !@include_unpublished
            next unless data.did_note_types.include?(note['type'] && note["publish"] == true)

            #audatt = note["publish"] === false ? {:audience => 'internal'} : {}
            content = ASpaceExport::Utils.extract_note_text(note, @include_unpublished)

            att = { :id => prefix_id(note['persistent_id']) }.reject {|k,v| v.nil? || v.empty? || v == "null" }
            att ||= {}

            case note['type']
            when 'dimensions', 'physfacet'
              #xml.physdesc(audatt) {
              xml.physdesc {
                generate_xml(content, xml, fragments, note['type'], att)
              }
            else
              #att.merge!(audatt)
              if note['type'] == 'langmaterial'
                label = { :label => "Language of Materials note" }
                att.merge!(label)
              end
              generate_xml(content, xml, fragments, note['type'], att)
            end
          end
        end

        def generate_xml(content, xml, fragments, node, attributes)
          xml.send(node, attributes) {
            sanitize_mixed_content(content, xml, fragments,ASpaceExport::Utils.include_p?(node))
          }
        end

        def customize_ead_data(custom_text,data)
          custom_text + data
        end

        def upcase_initial_char(string)
          reformat_string = string
          get_match = /(^[a-z])(.*)/.match(string)
          if get_match
            reformat_string = get_match[1].upcase + get_match[2]
          end
          reformat_string
        end

        def serialize_nondid_notes(data, xml, fragments)
          data.notes.each do |note|
            next if note["publish"] === false && !@include_unpublished
            next if note['internal']
            next if note['type'].nil?
            next unless (data.archdesc_note_types.include?(note['type']) and note["publish"] == true)
            if note['type'] == 'legalstatus'
              xml.accessrestrict {
                serialize_note_content(note, xml, fragments)
              }
            else
              serialize_note_content(note, xml, fragments)
            end
          end
        end

        #not sure if I should do this
        def serialize_did_notes(data, xml, fragments)
          data.notes.each do |note|
            next if note["publish"] === false && !@include_unpublished
            next unless (data.did_note_types.include?(note['type'])  and note["publish"] == true)

            #audatt = note["publish"] === false ? {:audience => 'internal'} : {}
            content = ASpaceExport::Utils.extract_note_text(note, @include_unpublished)

            att = { :id => prefix_id(note['persistent_id']) }.reject {|k,v| v.nil? || v.empty? || v == "null" }
            att ||= {}

            case note['type']
            when 'dimensions', 'physfacet'
              #xml.physdesc(audatt) {
              xml.physdesc {
                xml.send(note['type'], att) {
                  sanitize_mixed_content( content, xml, fragments, ASpaceExport::Utils.include_p?(note['type'])  )
                }
              }
            else
              xml.send(note['type'], att) {
                sanitize_mixed_content(content, xml, fragments,ASpaceExport::Utils.include_p?(note['type']))
              }
            end
          end
        end

        def serialize_container(inst, xml, fragments)

          atts = {}

          sub = inst['sub_container']
          top = sub['top_container']['_resolved']

          atts[:id] = prefix_id(SecureRandom.hex)
          last_id = atts[:id]

          atts[:type] =  upcase_initial_char(top['type'])

          text = top['indicator']

          atts[:label] = upcase_initial_char(I18n.t("enumerations.instance_instance_type.#{inst['instance_type']}",
            :default => inst['instance_type']))
            atts[:label] << " [#{top['barcode']}]" if top['barcode']

            if (cp = top['container_profile'])
              atts[:altrender] = cp['_resolved']['url'] || cp['_resolved']['name']
            end
            #binding.remote_pry if atts[:label] =~ /31142063173390/
            xml.container(atts) {

              sanitize_mixed_content(text, xml, fragments)
            }

            (2..3).each do |n|
              atts = {}

              next unless sub["type_#{n}"]

              atts[:id] = prefix_id(SecureRandom.hex)
              atts[:parent] = last_id
              last_id = atts[:id]

              atts[:type] =  upcase_initial_char(sub["type_#{n}"])
              text = sub["indicator_#{n}"]

              xml.container(atts) {
                sanitize_mixed_content(text, xml, fragments)
              }
            end
          end
          def serialize_digital_object(digital_object, xml, fragments)
            return if digital_object["publish"] === false && !@include_unpublished
            return if digital_object["suppressed"] === true

            file_versions = digital_object['file_versions']
            title = digital_object['title']
            date = digital_object['dates'][0] || {}

            atts = digital_object["publish"] === false ? {:audience => 'internal'} : {}

            content = ""
            content << title if title
            content << ": " if date['expression'] || date['begin']
            if date['expression']
              content << date['expression']
            elsif date['begin']
              content << date['begin']
              if date['end'] != date['begin']
                content << "-#{date['end']}"
              end
            end
            atts[@xlink_namespace+':title'] = digital_object['title'] if digital_object['title']


            if file_versions.empty?
              atts[@xlink_namespace+':type'] = 'simple'
              atts[@xlink_namespace+':href'] = digital_object['digital_object_id']
              atts[@xlink_namespace+':actuate'] = 'onRequest'
              atts[@xlink_namespace+':show'] = 'new'
              xml.dao(atts) {
                xml.daodesc{ sanitize_mixed_content(content, xml, fragments, true) } if content
              }
            elsif file_versions.length == 1
              #binding.remote_pry
              use = file_versions.first['use_statement'] if file_versions.first['use_statement']
              atts[@xlink_namespace+':type'] = 'simple'
              atts[@xlink_namespace+':href'] = file_versions.first['file_uri'] || digital_object['digital_object_id']
              atts[@xlink_namespace+':actuate'] = file_versions.first['xlink_actuate_attribute'] || 'onRequest'
              atts[@xlink_namespace+':show'] = file_versions.first['xlink_show_attribute'] || 'new'
              atts[@xlink_namespace+':role'] = I18n.t("enumerations.file_version_use_statement.#{use}") if use

              xml.dao(atts) {
                xml.daodesc{ sanitize_mixed_content(content, xml, fragments, true) } if content
              }
            else
              xml.daogrp( atts.merge( { @xlink_namespace+':type' => 'extended'} ) ) {
                xml.daodesc{ sanitize_mixed_content(content, xml, fragments, true) } if content
                file_versions.each do |file_version|
                  use = file_versions.first['use_statement'] if file_versions.first['use_statement']
                  atts[@xlink_namespace+':type'] = 'locator'
                  atts[@xlink_namespace+':href'] = file_version['file_uri'] || digital_object['digital_object_id']
                  atts[@xlink_namespace+':role'] = file_version['use_statement'] if file_version['use_statement']
                  atts[@xlink_namespace+':title'] = file_version['caption'] if file_version['caption']
                  atts['ns2:role'] = I18n.t("enumerations.file_version_use_statement.#{use}") if use
                  xml.daoloc(atts)
                end
              }
            end
          end


          def serialize_child(data, xml, fragments, c_depth = 1)
            begin
              return if data["publish"] === false && !@include_unpublished
              return if data["publish"] === false
              tag_name = @use_numbered_c_tags ? :"c#{c_depth.to_s.rjust(2, '0')}" : :c

              atts = {:level => data.level, :otherlevel => data.other_level, :id => prefix_id(data.ref_id)}

              #if data.publish === false
              #atts[:audience] = 'internal'
              #end

              atts.reject! {|k, v| v.nil?}
              xml.send(tag_name, atts) {

                xml.did {
                  if (val = data.title)
                    xml.unittitle {  sanitize_mixed_content( val,xml, fragments) }
                  end

                  if !data.component_id.nil? && !data.component_id.empty?
                    xml.unitid data.component_id
                  end

                  if @include_unpublished
                    data.external_ids.each do |exid|
                      xml.unitid  ({ "audience" => "internal",  "type" => exid['source'], "identifier" => exid['external_id']}) { xml.text exid['external_id']}
                    end
                  end

                  serialize_origination(data, xml, fragments)
                  serialize_extents(data, xml, fragments)
                  serialize_dates(data, xml, fragments)
                  serialize_did_notes(data, xml, fragments)

                  EADSerializer.run_serialize_step(data, xml, fragments, :did)

                  data.instances_with_sub_containers.each do |instance|
                    serialize_container(instance, xml, @fragments)
                  end
                }
                #binding.remote_pry
                if @include_daos
                  data.instances_with_digital_objects.each do |instance|
                    serialize_digital_object(instance['digital_object']['_resolved'], xml, fragments)
                  end
                end
                serialize_nondid_notes(data, xml, fragments)

                serialize_bibliographies(data, xml, fragments)

                serialize_indexes(data, xml, fragments)

                serialize_controlaccess(data, xml, fragments)

                EADSerializer.run_serialize_step(data, xml, fragments, :archdesc)

                data.children_indexes.each do |i|
                  xml.text(
                    @stream_handler.buffer {|xml, new_fragments|
                      serialize_child(data.get_child(i), xml, new_fragments, c_depth + 1)
                    }
                  )
                end
              }
            rescue => e
              xml.text "ASPACE EXPORT ERROR : YOU HAVE A PROBLEM WITH YOUR EXPORT OF ARCHIVAL OBJECTS. THE FOLLOWING INFORMATION MAY HELP:\n

              MESSAGE: #{e.message.inspect}  \n
              TRACE: #{e.backtrace.inspect} \n "
            end
          end

          def serialize_eadheader(data, xml, fragments)
            eadheader_atts = {:findaidstatus => data.finding_aid_status,
              :repositoryencoding => "iso15511",
              :countryencoding => "iso3166-1",
              :dateencoding => "iso8601",
              :langencoding => "iso639-2b"}.reject{|k,v| v.nil? || v.empty? || v == "null"}

              xml.eadheader(eadheader_atts) {

                eadid_atts = {:countrycode => data.repo.country,
                  :url => data.ead_location,
                  :mainagencycode => data.mainagencycode}.reject{|k,v| v.nil? || v.empty? || v == "null" }

                  xml.eadid(eadid_atts) {
                    xml.text data.ead_id
                  }

                  xml.filedesc {

                    xml.titlestmt {

                      titleproper = ""
                      titleproper += "#{data.finding_aid_title} " if data.finding_aid_title
                      titleproper += "#{data.title}" if ( data.title && titleproper.empty? )
                      titleproper += "<num>#{(0..3).map{|i| data.send("id_#{i}")}.compact.join('.')}</num>"
                      xml.titleproper("type" => "filing") { sanitize_mixed_content(data.finding_aid_filing_title, xml, fragments)} unless data.finding_aid_filing_title.nil?
                      xml.titleproper {  sanitize_mixed_content(titleproper, xml, fragments) }
                      xml.subtitle {  sanitize_mixed_content(data.finding_aid_subtitle, xml, fragments) } unless data.finding_aid_subtitle.nil?
                      if data.finding_aid_author
                        author = data.finding_aid_author
                        author = customize_ead_data("Collection processed by ",author)
                        xml.author { sanitize_mixed_content(author, xml, fragments) }
                      end
                      xml.sponsor { sanitize_mixed_content( data.finding_aid_sponsor, xml, fragments) } unless data.finding_aid_sponsor.nil?

                    }

                    unless data.finding_aid_edition_statement.nil?
                      xml.editionstmt {
                        sanitize_mixed_content(data.finding_aid_edition_statement, xml, fragments, true )
                      }
                    end

                    xml.publicationstmt {
                      xml.publisher { sanitize_mixed_content(data.repo.name,xml, fragments) }

                      if data.repo.image_url
                        xml.p ( { "id" => "logostmt" } ) {
                          xml.extref ({"ns2:href" => data.repo.image_url,
                            "ns2:actuate" => "onLoad",
                            "ns2:show" => "embed",
                            "ns2:type" => "simple"
                            })
                          }
                        end
                        unless data.addresslines.empty?
                          xml.address {
                            data.addresslines.each do |line|
                              xml.addressline { sanitize_mixed_content( line, xml, fragments) }
                            end
                          }
                        end
                      }

                      if (data.finding_aid_series_statement)
                        val = data.finding_aid_series_statement
                        xml.seriesstmt {
                          sanitize_mixed_content(  val, xml, fragments, true )
                        }
                      end
                      if ( data.finding_aid_note )
                        val = data.finding_aid_note
                        xml.notestmt { xml.note { sanitize_mixed_content(  val, xml, fragments, true )} }
                      end

                    }

                    xml.profiledesc {
                      # generates time as 2016-03-16T11:56-0400Z and the
                      # gsub removes the 'Z'
                      creation = "This finding aid was produced using ArchivesSpace <date>#{Time.now.utc.iso8601.gsub!('Z','')}</date>"
                      xml.creation {  sanitize_mixed_content( creation, xml, fragments) }

                      if (val = data.finding_aid_language)
                        xml.langusage (fragments << val)
                      end

                      if (val = data.descrules)
                        xml.descrules { sanitize_mixed_content(val, xml, fragments) }
                      end
                    }

                    if data.revision_statements.length > 0
                      xml.revisiondesc {
                        data.revision_statements.each do |rs|
                          if rs['description'] && rs['description'].strip.start_with?('<')
                            xml.text (fragments << rs['description'] )
                          else
                            xml.change {
                              rev_date = rs['date'] ? rs['date'] : ""
                              xml.date (fragments <<  rev_date )
                              xml.item (fragments << rs['description']) if rs['description']
                            }
                          end
                        end
                      }
                    end
                  }
                end
              end
