module ScimRails
  class ScimGroupsController < ScimRails::ApplicationController
    def index
      if params[:filter].present?
        query = ScimRails::ScimQueryParser.new("Group", params[:filter])

        groups = @company
          .public_send(ScimRails.config.scim_groups_scope)
          .where(
            "#{ScimRails.config.scim_groups_model.connection.quote_column_name(query.attribute)} #{query.operator} ?",
            query.parameter
          )
          .order(ScimRails.config.scim_groups_list_order)
      else
        groups = @company
          .public_send(ScimRails.config.scim_groups_scope)
          .order(ScimRails.config.scim_groups_list_order)
      end

      counts = ScimCount.new(
        start_index: params[:startIndex],
        limit: params[:count],
        total: groups.count
      )

      json_scim_response(object: groups, counts: counts)
    end

    def create
      display_name_key = ScimRails.config.queryable_group_attributes[:displayName]
      find_by_display_name = Hash.new
      find_by_display_name[display_name_key] = permitted_group_params[display_name_key]
      group = @company
        .public_send(ScimRails.config.scim_groups_scope)
        .find_or_create_by(find_by_display_name)
      group.update!(permitted_group_params)
      json_scim_response(object: group, status: :created)
    end

    def show
      group = @company.public_send(ScimRails.config.scim_groups_scope).find(params[:id])
      json_scim_response(object: group)
    end

    def put_update
      group = @company.public_send(ScimRails.config.scim_groups_scope).find(params[:id])
      group.update!(permitted_group_params)
      json_scim_response(object: group)
    end

    # PATCH update:
    # - Update Group [Non-member attributes]
    # - Update Group [Add Members]
    # - Update Group [Remove Members]
    def patch_update
      group = @company.public_send(ScimRails.config.scim_groups_scope).find(params[:id])
      update_display_name(group) if patch_display_name_param.present?
      json_scim_response(object: group)
    end

    private

    def permitted_group_params
      ScimRails.config.mutable_group_attributes.each.with_object({}) do |attribute, hash|
        hash[attribute] = find_value_for(attribute)
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

    def path_for(attribute, object = ScimRails.config.mutable_group_attributes_schema, path = [])
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

    def update_display_name(group)
      group.update!(display_name: patch_display_name_param)
    end

    def patch_display_name_param
      displayName = params.dig("Operations", 0, "value", "displayName")
      raise ScimRails::ExceptionHandler::UnsupportedPatchRequest if displayName.nil?
      displayName
    end
  end
end