require 'jwt'

module ScimRails
  class ApplicationController < ActionController::API
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ExceptionHandler
    include Response

    before_action :authorize_request

    private

    def authorize_request
      if request.headers['Authorization'].present? && request.headers['Authorization'].include?("Bearer")
        oauth_authorize
      else
        basic_auth_authorize
      end

      raise  ScimRails::ExceptionHandler::InvalidCredentials if @company.blank?
    end

    def oauth_authorize
      token = request.headers['Authorization'].split(' ').last
      authorization_data = JWT.decode(token, ENV["HMAC_SECRET"], true, { algorithm: ENV["HMAC_ALGORITHM"] }).first.deep_symbolize_keys

      authorization = AuthorizeApiRequest.new(
        searchable_attribute: authorization_data[:subdomain],
        authentication_attribute: authorization_data[:api_token]
      )

      @company = authorization.company
    end

    def basic_auth_authorize
      authenticate_with_http_basic do |username, password|
        authorization = AuthorizeApiRequest.new(
          searchable_attribute: username,
          authentication_attribute: password
        )
        @company = authorization.company
      end
    end
  end
end
