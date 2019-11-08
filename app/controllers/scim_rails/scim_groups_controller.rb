module ScimRails
  class ScimGroupsController < ScimRails::ApplicationController
    def index
      if params[:filter].present?
        query = ScimRails::ScimQueryParser.new("Group", params[:filter])

        groups = @company
          .public_send(ScimRails.config.scim_groups_scope)
          .where(
            query.attribute => query.parameter
          )
          .order_by(ScimRails.config.scim_groups_list_order)
      else
        groups = @company
          .public_send(ScimRails.config.scim_groups_scope)
          .order_by(ScimRails.config.scim_groups_list_order)
      end

      counts = ScimCount.new(
        start_index: params[:startIndex],
        limit: params[:count],
        total: groups.count
      )

      excluded_attributes = params[:excludedAttributes]

      json_scim_response(object: groups, counts: counts, excluded_attributes: excluded_attributes)
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

      excluded_attributes = params[:excludedAttributes]
      
      json_scim_response(object: group, excluded_attributes: excluded_attributes)
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

      if patch_path == :members
        case patch_operation.downcase
        when "add"
          add_members(group) if members_param.present?
        when "remove"
          remove_members(group) if members_param.present?
        end
      else
        update_attribute(group)
      end

      json_scim_response(object: group)
    end

    def destroy
      group = @company.public_send(ScimRails.config.scim_groups_scope).find(params[:id])
      group.destroy

      json_scim_response(object: nil)
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

    def update_attribute(group)
      group.update!(patch_path.to_sym => patch_value)
    end

    def add_members(group)
      group.public_send(ScimRails.config.group_add_members_method, members_param)
    end

    def remove_members(group)
      group.public_send(ScimRails.config.group_remove_members_method, members_param)
    end

    def patch_operation
      operation = params.dig("Operations", 0, "op")
    end

    def patch_path(object = ScimRails.config.mutable_group_attributes_schema)
      path = params.dig("Operations", 0, "path")
      path = object[path.to_sym]
    end

    def patch_value
      value = params.dig("Operations", 0, "value")

      case value
      when Hash
        value = value[:value]
      when Array
        value = value.first[:value]
      end

      return value
    end

    def patch_display_name_param
      displayName = params.dig("Operations", 0, "value", "displayName")
      raise ScimRails::ExceptionHandler::UnsupportedPatchRequest if displayName.nil?
      displayName
    end

    def members_param
      members = params.dig("Operations", 0, "value").map{|v| v["value"] }
      raise ScimRails::ExceptionHandler::UnsupportedPatchRequest if members.nil?
      members
    end
  end
end
