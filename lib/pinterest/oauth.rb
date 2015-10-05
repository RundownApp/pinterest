require 'openssl'
require 'base64'
require 'securerandom'

module Pinterest
  class OAuth
    attr_reader :app_id, :app_secret, :oauth_callback_url

    def initialize(app_id, app_secret, oauth_callback_url = nil)
      @app_id = app_id
      @app_secret = app_secret
      @oauth_callback_url = oauth_callback_url

      @transport = Pinterest::Transport.new
    end

    # Builds an OAuth URL, where users will be prompted to log in and for any desired permissions.
    # When the users log in, you receive a callback with their
    # See https://developers.pinterest.com/docs/api/authentication/.
    #
    # @see #url_for_access_token
    #
    # @param options any query values to add to the URL, as well as any special/required values listed below.
    # @option options permissions an array or comma-separated string of desired permissions
    # @option options state a unique string to serve as a CSRF (cross-site request
    #                 forgery) token -- highly recommended for security. See
    #                 https://developers.facebook.com/docs/howtos/login/server-side-login/
    #
    # @raise ArgumentError if no OAuth callback was specified in OAuth#new or in options as :redirect_uri
    #
    # @return an OAuth URL you can send your users to
    def url_for_oauth_code(options = {})
      # for scopes, see https://developers.pinterest.com/docs/api/overview/#scopes
      if scopes = options.delete(:scopes)
        options[:scope] = scopes.is_a?(Array) ? scopes.join(',') : scopes
      end

      if state = options.delete(:state)
        options[:state] = state
      else
        options[:state] = SecureRandom.hex(10)
      end

      options[:response_type] = code

      url_options = {:client_id => @app_id}.merge(options)

      build_url('oauth', true, url_options)
    end

    # access tokens

    # Fetches an access token, token expiration, and other info from Pinterest.
    # Useful when you've received an OAuth code using the server-side authentication process.
    # @see url_for_oauth_code
    #
    # @note (see #url_for_oauth_code)
    #
    # @param code (see #url_for_access_token)
    #
    # @raise Pinterest::OAuthTokenRequestError if Facebook returns an error response
    #
    # @return a hash of the access token info returned by Pinterest (token, expiration, etc.)
    def get_access_token_info(code)
      # convenience method to get a parsed token from Pinterest for a given code
      # should this require an OAuth callback URL?
      get_token_from_server({:code => code, :redirect_uri => options[:redirect_uri] || @oauth_callback_url})
    end

    # Fetches the access token (ignoring expiration and other info) from Pinterest.
    # Useful when you've received an OAuth code using the server-side authentication process.
    # @see get_access_token_info
    #
    # @note (see #url_for_oauth_code)
    #
    # @param (see #get_access_token_info)
    #
    # @raise (see #get_access_token_info)
    #
    # @return the access token
    def get_access_token(code)
      # upstream methods will throw errors if needed
      if info = get_access_token_info(code)
        string = info['access_token']
      end
    end

    def get_token_from_server(args)
      # fetch the result from Facebook's servers
      response = fetch_token_string(args, 'token')
      parse_access_token(response)
    end

    def parse_access_token(response_text)
      MultiJson.load(response_text)
    rescue MultiJson::LoadError
      response_text.split('&').inject({}) do |hash, bit|
        key, value = bit.split('=')
        hash.merge!(key => value)
      end
    end

    def fetch_token_string(args, endpoint = 'token')
      response = @transport.post("/oauth/#{endpoint}", {
                                                          :client_id => @app_id,
                                                          :client_secret => @app_secret
                                                      }.merge!(args))

      #raise ServerError.new(response.status, response.body) if response.status >= 500
      #raise OAuthTokenRequestError.new(response.status, response.body) if response.status >= 400

      response.body
    end

    def build_url(path, require_redirect_uri = false, url_options = {})
      if require_redirect_uri && !(url_options[:redirect_uri] ||= url_options.delete(:callback) || @oauth_callback_url)
        raise ArgumentError, 'build_url must get a callback either from the OAuth object or in the parameters!'
      end
      params = Pinterest::Transport.encode_params(url_options)
      "https://api.pinterest.com/#{path}?#{params}"
    end
  end
end