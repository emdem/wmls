#!/usr/bin/env ruby -w
# Copyright 2011 Wellstorm Development LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require 'net/http'
require 'net/https'
require 'uri'
require 'stringio'
require 'nokogiri'

# A WITSML client library. 
#
# Author:: Hugh Winkler
# Copyright:: 2011 Wellstorm Development
# License:: Apache 2.0

# A WITSML client library. Construct an instance with the URL of the WITSML service,
# and credentials. Then call the WMLS methods, passing a WITSML query 
# template to each method.

class Wmls

  # The HTTP timeout in seconds (default 60)
  attr_accessor :timeout

  # Construct a new Wmls instance. 
  # url The URL of the remote WMLS service
  # user_name, password Credentials for the remote service

  def initialize (url, user_name, password)
    @url = url
    @user_name = user_name
    @password = password

    @optionsIn = ''
    @capabilitiesIn = ''
    @timeout = 60

    @envelope_begin = <<END
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:ns0="http://www.witsml.org/message/120">
    <SOAP-ENV:Header/>
    <SOAP-ENV:Body>
END

    @envelope_end = <<END
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
END
  end

  # call WMLS_AddToStore with the given template
  def add_to_store(template, optionsIn=nil, headers={})
    wmlTypeIn = extract_type(template)
    queryIn = escape_xml(template)
    soap_action = 'http://www.witsml.org/action/120/Store.WMLS_AddToStore'
    headers['SOAPAction'] = soap_action
    envelope_middle = <<END
        <ns0:WMLS_AddToStore SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <WMLtypeIn>#{wmlTypeIn}</WMLtypeIn>
            <XMLin>#{queryIn}</XMLin>
            <OptionsIn>#{optionsIn || @optionsIn}</OptionsIn>
            <CapabilitiesIn>#{@capabilitiesIn}</CapabilitiesIn>
        </ns0:WMLS_AddToStore>
END
    return send envelope_middle, headers
  end

  # call WMLS_DeleteStore with the given template
  def delete_from_store(template, optionsIn = nil, headers={})
    wmlTypeIn = extract_type(template)
    queryIn = escape_xml(template)
    soap_action = 'http://www.witsml.org/action/120/Store.WMLS_DeleteFromStore'
    headers['SOAPAction'] = soap_action
    envelope_middle = <<END
        <ns0:WMLS_DeleteFromStore SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <WMLtypeIn>#{wmlTypeIn}</WMLtypeIn>
            <QueryIn>#{queryIn}</QueryIn>
            <OptionsIn>#{optionsIn || @optionsIn}</OptionsIn>
            <CapabilitiesIn>#{@capabilitiesIn}</CapabilitiesIn>
        </ns0:WMLS_DeleteFromStore>
END
    return send envelope_middle, headers
  end

  # call WMLS_UpdateInStore with the given template
  def update_in_store(template, optionsIn=nil, headers={})
    wmlTypeIn = extract_type(template)
    queryIn = escape_xml(template)
    soap_action = 'http://www.witsml.org/action/120/Store.WMLS_UpdateInStore'
    headers['SOAPAction'] = soap_action
    envelope_middle = <<END
        <ns0:WMLS_UpdateInStore SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <WMLtypeIn>#{wmlTypeIn}</WMLtypeIn>
            <XMLin>#{queryIn}</XMLin>
            <OptionsIn>#{optionsIn || @optionsIn}</OptionsIn>
            <CapabilitiesIn>#{@capabilitiesIn}</CapabilitiesIn>
        </ns0:WMLS_UpdateInStore>
END
    return send envelope_middle, headers
  end
  
  # call WMLS_GetFromStore with the given template
  def get_from_store(template, optionsIn=nil, headers={})
    wmlTypeIn = extract_type(template)
    queryIn = escape_xml(template)
    soap_action = 'http://www.witsml.org/action/120/Store.WMLS_GetFromStore'
    headers['SOAPAction'] = soap_action
    envelope_middle = <<END
        <ns0:WMLS_GetFromStore SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <WMLtypeIn>#{wmlTypeIn}</WMLtypeIn>
            <QueryIn>#{queryIn}</QueryIn>
            <OptionsIn>#{optionsIn || @optionsIn}</OptionsIn>
            <CapabilitiesIn>#{@capabilitiesIn}</CapabilitiesIn>
        </ns0:WMLS_GetFromStore>
END
    return send envelope_middle, headers
  end

  # call WMLS_GetCap with the specified optionsIn. 
  def get_cap(optionsIn=nil, headers={})
    soap_action = 'http://www.witsml.org/action/120/Store.WMLS_GetCap'
    headers['SOAPAction'] = soap_action
    envelope_middle = <<END
        <ns0:WMLS_GetCap SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <OptionsIn>#{optionsIn || @optionsIn}</OptionsIn>
        </ns0:WMLS_GetCap>
END
    return send envelope_middle, headers 
  end

  private

  # Replace special xml characters '&' and '<'
  def escape_xml(xml_in) 
    return xml_in.gsub(/&/,'&amp;').gsub(/</,'&lt;')
  end

  def pretty_xml(xml_data)
    doc = Nokogiri::XML(xml_data)
    return doc.to_xml
  end

  # parse the xml and return the singular of the root element name.
  def extract_type(xml_data)
    doc = Nokogiri::XML(xml_data)
    plural = doc.root.name
    return plural[0..plural.length-2]
  end

  #extract the witsml response: status_code and xml_out
  def extract_response(xml_data)
    doc = Nokogiri::XML(xml_data)
    r = 0
    x = ''
    s = ''
    doc.xpath('//Result').each() { |elt| r = elt.text }
    doc.xpath('//XMLout').each() { |elt| x = pretty_xml(elt.text) }
    doc.xpath('//CapabilitiesOut').each() { |elt| x = pretty_xml(elt.text) }
    doc.xpath('//SuppMsgOut').each() { |elt| s = elt.text }
    return [r.to_i,s,x];
  end

  #write the witsml response xml to a csv file
  def write_csv_file(xml_data, filename)
    doc = Nokogiri::XML(xml_data)
    csv = CSV.open(filename, "wb")
    csv << 'asdfasdf,asdf' 
  end

  def post(io, url, user, pass, headers)    
    url = URI.parse(url)  if url.is_a? String
    io = StringIO.new(io) if io.is_a? String

    req = Net::HTTP::Post.new(url.path)
    req.basic_auth user, pass if user && user.length > 0
    req.body_stream = io

    #soap 1.1:
    #req.add_field('SOAPAction', soap_action)
    headers.each_pair {|header, value| req.add_field(header, value)}
    req.content_type = 'text/xml' 

    #soap 1.2 would replace the above with:
    #req.content_type = "application/soap+xml; action=#{soap_action}"

    #req.content_length = io.stat.size
    req.content_length = io.size   # specific to StringIO class ? why no stat on that class?
    http = Net::HTTP.new(url.host, url.port)  
    http.use_ssl = (url.scheme == "https")
    http.read_timeout = @timeout # secs
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    res = http.start {|http2| http2.request(req) }

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      # OK
      res
    else
      res.error!
    end
  end


  def send(envelope_middle, headers)
    envelope = @envelope_begin + envelope_middle + @envelope_end
    response = post(envelope, @url, @user_name, @password, headers)
    extract_response(response.body)
  end


end
