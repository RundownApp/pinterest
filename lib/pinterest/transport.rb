module Pinterest
  class Transport
    def initialize
      @conn = Faraday.new(:url => 'https://api.pinterest.com/v1/') do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
    end

    def post(path, body)
      @conn.post do |req|
        req.url path
        req.headers['Content-Type'] = 'application/json'
        req.body = body
      end
    end

    def get(path, params = {})
      @conn.get path, params
    end

    # Encodes a given hash into a query string.
    # This is used mainly by the Batch API nowadays, since Faraday handles this for regular cases.
    #
    # @param params_hash a hash of values to CGI-encode and appropriately join
    #
    # @example
    #   Koala.http_service.encode_params({:a => 2, :b => "My String"})
    #   => "a=2&b=My+String"
    #
    # @return the appropriately-encoded string
    def self.encode_params(param_hash)
      ((param_hash || {}).sort_by{|k, v| k.to_s}.collect do |key_and_value|
        key_and_value[1] = MultiJson.dump(key_and_value[1]) unless key_and_value[1].is_a? String
        "#{key_and_value[0].to_s}=#{CGI.escape key_and_value[1]}"
      end).join("&")
    end
  end
end