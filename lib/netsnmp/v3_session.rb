module NETSNMP
  class V3Session < Session

    def build_pdu(type, *oids)
      engine_id = security_parameters.engine_id
      context   = @options.fetch(:context, "")
      pdu = ScopedPDU.build(type, headers: [engine_id, context], varbinds: oids)
    end

    def send(*)
      pdu, _ = super
      pdu
    end

    private

    def validate_options(options)
      options = super
      options[:security_level] = case options[:security_level]
        when /no_?auth/         then 0
        when /auth_?no_?priv/   then 1
        when /auth_?priv/, nil  then 3
        when Integer
          options[:security_level]
      end
      options
    end

    def security_parameters
      @security_parameters ||= begin
        engine_id = probe_for_engine
        SecurityParameters.new(security_level: @options[:security_level], 
                               username: @options[:username],
                               engine_id: engine_id,
                               auth_protocol: @options[:auth_protocol],
                               priv_protocol: @options[:priv_protocol],
                               auth_password: @options[:auth_password],
                               priv_password: @options[:priv_password])
      end 
    end

    # sends a probe snmp v3 request, to get the additional info with which to handle the security aspect
    #
    def probe_for_engine
      report_sec_params = SecurityParameters.new(security_level: 0,
                                                 username: @options[:username])
      pdu = ScopedPDU.build(:get, headers: [])
      encoded_report_pdu = Message.encode(pdu, security_parameters: report_sec_params)

      encoded_response_pdu = @transport.send(encoded_report_pdu)

      _, engine_id, @engine_boots, @engine_time = decode(encoded_response_pdu, security_parameters: report_sec_params)
      engine_id
    end

    def encode(pdu)
      Message.encode(pdu, security_parameters: @security_parameters, 
                          engine_boots: @engine_boots,
                          engine_time: @engine_time)
    end

    def decode(stream, security_parameters: @security_parameters)
      Message.decode(stream, security_parameters: security_parameters)
    end
  end
end
