#!/usr/bin/env ruby

require 'nokogiri'
require 'liquid'

require 'io/console'

module Booxygen
  VERSION = "0.3.3"

  class Templates
    def initialize(dir)

    end
  end

  class Doxygen
    def initialize
      @index_hash = {}
    end

    # Fonction de traitement des différents fichiers XML
    def parse_compound(ref_file)
      xml = Nokogiri::XML(File.open("#{$dir}#{ref_file}.xml"))

      xsd_name = xml.at_xpath('//doxygen')['xsi:noNamespaceSchemaLocation']
      xsd = Nokogiri::XML(File.open("#{$dir}#{xsd_name}"))

      xsd_doxygen_element = xsd.at_xpath('//xsd:element[@name=\'doxygen\']')

      rec_parse(xsd_doxygen_element, xsd, xml.at_xpath('//doxygen'))
    end

    # Fonction de traitement d'un type donné dans un code XML donné
    def rec_parse(index, xsd, xml)
      result = {}

      # Recherche des caractéristiques du type complexe donné
      xsd_complex_type = xsd.at_xpath("//xsd:complexType[@name='#{index['type']}']")

      # Récupération des éléments et attributs
      xsd_elements_list = xsd_complex_type.xpath('.//xsd:element')
      xsd_attributs_list = xsd_complex_type.xpath('.//xsd:attribute')
      #xsd_group_list = xsd_complex_type.xpath('.//xsd:group')

      # S'il n'y a aucun élément et aucun attribut
      if xsd_elements_list.all? {|x| x.nil?} && xsd_attributs_list.all? {|x| x.nil?}
        return xml.to_s
      else

        # Traitement des attributs
        xsd_attributs_list.each do |attribut|
          result[attribut['name']] = xml[attribut['name']]

          # Si c'est un type "CompoundKind", traiter son XML correspondant
          if attribut['type'] == 'CompoundKind'
            result['sub_xml'] = parse_compound(xml['refid'])
          end
        end

        # Traitement des éléments
        xsd_elements_list.each do |xsd_element|
          xml_elements_list = xml.xpath("./#{xsd_element['name']}")
          element_array = []

          xml_elements_list.each do |xml_element_code|

            if xsd_element['type'].nil? || xsd_element['type'].start_with?('xsd:')
              # Si c'est un type inconnu ou nul
              element_array.push xml_element_code.to_s
            else
              # Si c'est un type connu
              element_array.push rec_parse(xsd_element, xsd, xml_element_code)
            end
          end
          result[xsd_element['name']] = element_array
        end
      end

      result
    end

    # Fonction de traitement d'un fichier d'index
    def parse(xml_filename)
      xml = Nokogiri::XML(File.open("#{$dir}#{xml_filename}.xml"))

      xsd_name = xml.at_xpath('//doxygenindex')['xsi:noNamespaceSchemaLocation']
      xsd = Nokogiri::XML(File.open("#{$dir}#{xsd_name}"))

      xsd_doxygen_element = xsd.at_xpath('//xsd:element[@name=\'doxygenindex\']')

      @index_hash = rec_parse(xsd_doxygen_element, xsd, xml.at_xpath('//doxygenindex'))
    end

    # Fonction d'affichage
    def print_res
      compounds = []

      @index_hash['compound'].each do |value|
          compounds.push value
      end

      loop do
        template = Liquid::Template.parse(File.read('./templates/template1.liquid'))
        Liquid::Template.error_mode = :strict
        File.write('output/index.html', template.render('compounds' => compounds))

        print "\n", "Please press any key to reload Liquid..."
        if STDIN.getch == "q"
          print "\n"
          break
        end

      end
    end
  end

  def self.run
    dox = Doxygen.new
    dox.parse 'index'
    dox.print_res
  end
end

#
# Programme principal
#

if ARGV.length != 1
  print "Usage: booxygen <directory>\n"
  abort
end

if Dir.exist?(ARGV[0])
  # Définition d'une variable globale
  $dir = ARGV[0]
  Booxygen::run
else
  print "Unknown directory\n"
  abort
end
