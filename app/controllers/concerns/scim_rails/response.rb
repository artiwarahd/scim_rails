module ScimRails
  module Response
    CONTENT_TYPE = "application/scim+json".freeze

    def json_response(object, status = :ok)
      render \
        json: object,
        status: status,
        content_type: CONTENT_TYPE
    end

    def json_scim_response(object:, status: :ok, counts: nil, excluded_attributes: nil)
      render json: json_scim_not_found_response, status: :not_found and return if object.blank?

      case params[:action]
      when "index"
        render \
          json: list_response(object, counts, excluded_attributes),
          status: status,
          content_type: CONTENT_TYPE
      when "show", "create", "put_update", "patch_update"
        render \
          json: object_response(object, excluded_attributes),
          status: status,
          content_type: CONTENT_TYPE
      when "destroy"
        render \
          nothing: true,
          status: :no_content,
          content_type: CONTENT_TYPE
      end
    end

    private

    def list_response(object, counts, excluded_attributes)
      object = object
        .order_by(created_at: :asc)
        .offset(counts.offset)
        .limit(counts.limit)
      {
        "schemas": [
            "urn:ietf:params:scim:api:messages:2.0:ListResponse"
        ],
        "totalResults": counts.total,
        "startIndex": counts.start_index,
        "itemsPerPage": counts.limit,
        "Resources": list_objects(object, excluded_attributes)
      }
    end

    def json_scim_not_found_response
      {
        "schemas": [
            "urn:ietf:params:scim:api:messages:2.0:Error"
        ],
        "status": "404"
      }
    end

    def list_objects(records, excluded_attributes)
      records.map do |record|
        object_response(record, excluded_attributes)
      end
    end

    def object_response(object, excluded_attributes)
      case object.class.name
      when "User"
        schema = ScimRails.config.user_schema.clone
      when "Group"
        schema = ScimRails.config.group_schema.clone
      end

      schema.delete(excluded_attributes.to_sym) if excluded_attributes.present?

      find_value(object, schema)
    end


    # `find_value` is a recursive method that takes a "user" and a
    # "user schema" and replaces any symbols in the schema with the
    # corresponding value from the user. Given a schema with symbols,
    # `find_value` will search through the object for the symbols,
    # send those symbols to the model, and replace the symbol with
    # the return value.

    def find_value(object, schema)
      case schema
      when Hash
        schema.each.with_object({}) do |(key, value), hash|
          hash[key] = find_value(object, value)
        end
      when Array
        schema.map do |value|
          find_value(object, value)
        end
      when Symbol
        object.public_send(schema)
      else
        schema
      end
    end
  end
end
