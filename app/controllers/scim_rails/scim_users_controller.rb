module ScimRails
  class ScimUsersController < ScimRails::ApplicationController

    before_action :mapping_params

    def mapping_params
      params[:userName] = params.to_unsafe_h[:emails][0]["value"] if params[:emails].present?
    end

    def index
      if params[:filter].present?
        filter_string = params[:filter].gsub(/\[.*\]\.value/, "");
        query = ScimRails::ScimQueryParser.new("User", filter_string)

        users = @company
          .public_send(ScimRails.config.scim_users_scope)
          .where(
            query.attribute => query.parameter
          )
          .order_by(ScimRails.config.scim_users_list_order)
      else
        users = @company
          .public_send(ScimRails.config.scim_users_scope)
          .order_by(ScimRails.config.scim_users_list_order)
      end

      counts = ScimCount.new(
        start_index: params[:startIndex],
        limit: params[:count],
        total: users.count
      )

      json_scim_response(object: users, counts: counts)
    end

    def create
      username_key = ScimRails.config.queryable_user_attributes[:userName]
      find_by_username = Hash.new
      find_by_username[username_key] = permitted_user_params[username_key]
      user = @company
        .public_send(ScimRails.config.scim_users_scope)
        .find_or_create_by(find_by_username)
      user.update!(permitted_user_params)
      update_status(user) unless put_active_param.nil?
      json_scim_response(object: user, status: :created)
    end

    def show
      user = @company.public_send(ScimRails.config.scim_users_scope).find(params[:id])
      json_scim_response(object: user)
    end

    def put_update
      user = @company.public_send(ScimRails.config.scim_users_scope).find(params[:id])
      update_status(user) unless put_active_param.nil?
      user.update!(permitted_user_params)
      json_scim_response(object: user)
    end

    # TODO: PATCH will only deprovision or reprovision users.
    # This will work just fine for Okta but is not SCIM compliant.
    def patch_update
      user = @company.public_send(ScimRails.config.scim_users_scope).find(params[:id])
      update_status(user) unless patch_active_param.nil?
      user.update!(permitted_patch_user_params)
      json_scim_response(object: user)
    end

    private

    def permitted_user_params
      ScimRails.config.mutable_user_attributes.each.with_object({}) do |attribute, hash|
        hash[attribute] = find_value_for(attribute)
      end
    end

    def permitted_patch_user_params
      operations_data = params.to_unsafe_h[:Operations]

      ScimRails.config.mutable_user_attributes.each.with_object({}) do |attribute, hash|
        path = path_for(attribute).map(&:to_s).join(".")
        operation_data = operations_data.detect{|operation| operation["path"] == path }

        next if operation_data.blank?
        hash[attribute] = operation_data["value"]
      end
    end

    def find_value_for(attribute)
      params.dig(*path_for(attribute))
    end

    # `path_for` is a recursive method used to find the "path" for
    # `.dig` to take when looking for a given attribute in the
    # params.
    #
    # Example: `path_for(:name)` should return an array that looks
    # like [:names, 0, :givenName]. `.dig` can then use that path
    # against the params to translate the :name attribute to "John".

    def path_for(attribute, object = ScimRails.config.mutable_user_attributes_schema, path = [])
      at_path = path.empty? ? object : object.dig(*path)
      return path if at_path == attribute

      case at_path
      when Hash
        at_path.each do |key, value|
          found_path = path_for(attribute, object, [*path, key])
          return found_path if found_path
        end
        nil
      when Array
        at_path.each_with_index do |value, index|
          found_path = path_for(attribute, object, [*path, index])
          return found_path if found_path
        end
        nil
      end
    end

    def update_status(user)
      user.public_send(ScimRails.config.user_reprovision_method) if active?
      user.public_send(ScimRails.config.user_deprovision_method) unless active?
    end

    def active?
      active = put_active_param
      active = patch_active_param if active.nil?

      case active
      when true, "true", 1
        true
      when false, "false", 0
        false
      else
        raise ActiveRecord::RecordInvalid
      end
    end

    def put_active_param
      params[:active]
    end

    def patch_active_param
      active = (params.dig("Operations", 0, "value", "active") rescue nil)
    end
  end
end
