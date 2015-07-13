require 'open-uri'
require 'nokogiri'
require 'csv'

class Place < Struct.new(:a)
  def self.identifier=(identifier)
    @identifier = identifier
  end

  def self.identifier
    @identifier
  end

  def id
    url.match(/#{self.class.identifier}=(\d*)/)[1]
  end

  def name
    a.text
  end

  def url
    a.attributes['href'].to_s
  end
end

class State < Place
  self.identifier = "Estado"
end

class City < Place
  self.identifier = "VCodMunicipio"
end

class Establishment < Place
  self.identifier = "VCo_Unidade"

  def x
    @x ||= geo('latitude')
  end

  def y
    @y ||= geo('longitude')
  end

  def street
    @street ||= geo('Logradouro')
  end

  def number
    @number ||= geo('Numero')
  end

  def neighborhood
    @neighborhood ||= geo('Bairro')
  end

  private

  def geo(name)
    input = geo_html.css("input[name=#{name}]")[0]
    input ? input.attributes['value'].to_s : nil
  end

  def geo_html
    @geo_html ||= get "geo.asp?VUnidade=#{id}"
  end
end

def req(url)
  begin
    puts "requesting #{url}"
    open "http://cnes.datasus.gov.br/#{url}", read_timeout: 5
  rescue
    puts "Timeout"
    retry
  end
end

def get(url)
  Nokogiri::HTML req(url)
end

parsed_ids = CSV.open("sus.csv").map { |csv| csv[2] }

CSV.open("sus.csv", "a") do |csv|
  get("Lista_Tot_Es_Estado.asp").css("a[href*='Lista_Tot_Es_Municipio.asp']").each do |state|
    state = State.new state
    get(state.url).css("a[href*='Lista_Es_Municipio.asp']").each do |city|
      city = City.new city
      get(city.url).css("a[href*='Exibe_Ficha_Estabelecimento.asp']").each do |establishment|
        establishment = Establishment.new establishment
        csv << [state.id, city.id, establishment.id, establishment.name, establishment.x, establishment.y, establishment.street, establishment.number, establishment.neighborhood] unless parsed_ids.include?(establishment.id)
      end
    end
  end
end
