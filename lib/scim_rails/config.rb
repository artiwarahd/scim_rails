module ScimRails
  class << self
    def configure
      yield config
    end

    def config
      @_config ||= Config.new
    end
  end

  class Config
    attr_accessor \
      :basic_auth_model,
      :basic_auth_model_authenticatable_attribute,
      :basic_auth_model_searchable_attribute,
      :mutable_user_attributes,
      :mutable_user_attributes_schema,
      :queryable_user_attributes,
      :scim_users_list_order,
      :scim_users_model,
      :scim_users_scope,
      :user_attributes,
      :user_deprovision_method,
      :user_reprovision_method,
      :user_schema,
      :mutable_group_attributes,
      :mutable_group_attributes_schema,
      :queryable_group_attributes,
      :scim_groups_list_order,
      :scim_groups_model,
      :scim_groups_scope,
      :group_attributes,
      :group_deprovision_method,
      :group_reprovision_method,
      :group_schema
      
    def initialize
      @basic_auth_model = "Company"
      @scim_users_list_order = :id
      @scim_users_model = "User"
      @scim_groups_model = "Group"
      @user_schema = {}
      @user_attributes = []
      @group_schema = {}
      @group_attributes = []
    end

    def mutable_user_attributes_schema
      @mutable_user_attributes_schema || @user_schema
    end

    def mutable_group_attributes_schema
      @mutable_group_attributes_schema || @group_schema
    end

    def basic_auth_model
      @basic_auth_model.constantize
    end

    def scim_users_model
      @scim_users_model.constantize
    end

    def scim_groups_model
      @scim_groups_model.constantize
    end
  end
end
