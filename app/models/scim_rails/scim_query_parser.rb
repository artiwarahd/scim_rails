module ScimRails
  class ScimQueryParser
    attr_accessor :model_name, :query_elements

    def initialize(model_name, query_string)
      self.query_elements = query_string.split(" ")
      self.model_name = model_name
    end

    def attribute
      attribute = query_elements.dig(0)
      raise ScimRails::ExceptionHandler::InvalidQuery if attribute.blank?
      attribute = attribute.to_sym

      mapped_attribute = attribute_mapping(attribute)
      raise ScimRails::ExceptionHandler::InvalidQuery if mapped_attribute.blank?
      mapped_attribute
    end

    def operator
      sql_comparison_operator(query_elements.dig(1))
    end

    def parameter
      parameter = query_elements[2..-1].join(" ")
      return if parameter.blank?
      parameter.gsub(/"/, "")
    end

    private

    def attribute_mapping(attribute)
      case model_name
      when "User"
        ScimRails.config.queryable_user_attributes[attribute]
      when "Group"
        ScimRails.config.queryable_group_attributes[attribute]
      end
    end

    def sql_comparison_operator(element)
      case element
      when "eq"
        "="
      else
        # TODO: implement additional query filters
        raise ScimRails::ExceptionHandler::InvalidQuery
      end
    end
  end
end
