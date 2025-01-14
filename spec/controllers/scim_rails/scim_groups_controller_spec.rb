require "spec_helper"

RSpec.describe ScimRails::ScimGroupsController, type: :controller do
  include AuthHelper

  routes { ScimRails::Engine.routes }

  describe "index" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        get :index

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        get :index

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        get :index

        expect(response.status).to eq 401
      end
    end

    context "when when authorized" do
      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        get :index

        expect(response.content_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        get :index

        expect(response.status).to eq 200
      end

      it "returns all results" do
        create_list(:group, 10, company: company)

        get :index
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:ListResponse"
        expect(response_body["totalResults"]).to eq 10
      end

      it "defaults to 100 results" do
        create_list(:group, 300, company: company)

        get :index
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 300
        expect(response_body["Resources"].count).to eq 100
      end

      it "paginates results" do
        create_list(:group, 400, company: company)
        expect(company.groups.first.id).to eq 1

        get :index, params: {
          startIndex: 101,
          count: 200,
        }
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 400
        expect(response_body["Resources"].count).to eq 200
        expect(response_body.dig("Resources", 0, "id")).to eq 101
      end

      it "paginates results by configurable scim_groups_list_order" do
        allow(ScimRails.config).to receive(:scim_groups_list_order).and_return({ created_at: :desc })

        create_list(:group, 400, company: company)
        expect(company.groups.first.id).to eq 1

        get :index, params: {
          startIndex: 1,
          count: 10,
        }
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 400
        expect(response_body["Resources"].count).to eq 10
        expect(response_body.dig("Resources", 0, "id")).to eq 400
      end

      it "filters results by provided displayName filter" do
        create(:group, display_name: "Test Group #1", company: company)
        create(:group, display_name: "Test Group #2", company: company)

        get :index, params: {
          filter: "displayName eq Test Group #1"
        }
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 1
        expect(response_body["Resources"].count).to eq 1
      end

      it "returns no results for unfound filter parameters" do
        get :index, params: {
          filter: "displayName eq fake_not_there"
        }
        response_body = JSON.parse(response.body)
        expect(response_body["totalResults"]).to eq 0
        expect(response_body["Resources"].count).to eq 0
      end

      it "returns no results for undefined filter queries" do
        get :index, params: {
          filter: "address eq 101 Nowhere USA"
        }
        expect(response.status).to eq 400
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end
    end
  end


  describe "show" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        get :show, params: { id: 1 }

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        get :show, params: { id: 1 }

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        get :show, params: { id: 1 }

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        get :show, params: { id: 1 }

        expect(response.content_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        create(:group, id: 1, company: company)
        get :show, params: { id: 1 }

        expect(response.status).to eq 200
      end

      it "returns :not_found for id that cannot be found" do
        get :show, params: { id: "fake_id" }

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1)

        get :show, params: { id: 1 }

        expect(response.status).to eq 404
      end
    end
  end


  describe "create" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        post :create

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        post :create

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        post :create

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        post :create, params: {
          displayName: "Test Group #1"
        }

        expect(response.content_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        expect(company.groups.count).to eq 0

        post :create, params: {
          displayName: "Test Group #1"
        }

        expect(response.status).to eq 201
        expect(company.groups.count).to eq 1
        group = company.groups.first
        expect(group.persisted?).to eq true
        expect(group.display_name).to eq "Test Group #1"
        expect(group.members).to eq []
      end

      it "ignores unconfigured params" do
        post :create, params: {
          code: "12345",
          displayName: "Test Group #1"
        }

        expect(response.status).to eq 201
        expect(company.groups.count).to eq 1
      end

      it "returns 422 if required params are missing" do
        post :create, params: {}

        expect(response.status).to eq 422
        expect(company.groups.count).to eq 0
      end
    end
  end


  describe "put update" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        put :put_update, params: { id: 1 }

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        put :put_update, params: { id: 1 }

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        put :put_update, params: { id: 1 }

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      let!(:group) { create(:group, id: 1, company: company) }

      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        put :put_update, params: put_params

        expect(response.content_type).to eq "application/scim+json"
      end

      it "is successful with with valid credentials" do
        put :put_update, params: put_params

        expect(response.status).to eq 200
      end

      it "update group display name" do
        request.content_type = "application/scim+json"
        put :put_update, params: put_params(displayName: "New Display Name")

        expect(response.status).to eq 200
        expect(group.reload.display_name).to eq "New Display Name"
      end

      it "returns :not_found for id that cannot be found" do
        get :put_update, params: { id: "fake_id" }

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1000)

        get :put_update, params: { id: 1000 }

        expect(response.status).to eq 404
      end

      it "is returns 422 with incomplete request" do
        put :put_update, params: {
          id: 1,
          code: "Test Group #1",
          members: []
        }

        expect(response.status).to eq 422
      end
    end
  end


  describe "patch update" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        patch :patch_update, params: patch_params(id: 1)

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        patch :patch_update, params: patch_params(id: 1)

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        patch :patch_update, params: patch_params(id: 1)

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      let!(:group) { create(:group, id: 1, company: company) }

      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        patch :patch_update, params: patch_params(id: 1)

        expect(response.content_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        patch :patch_update, params: patch_params(id: 1)

        expect(response.status).to eq 200
      end

      it "returns :not_found for id that cannot be found" do
        get :patch_update, params: patch_params(id: "fake_id")

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1000)

        get :patch_update, params: patch_params(id: 1000)

        expect(response.status).to eq 404
      end

      it "successfully update group [Non-member attributes]" do
        expect(company.groups.count).to eq 1
        group = company.groups.first

        patch :patch_update, params: patch_params(id: 1, displayName: "New Display Name")

        expect(response.status).to eq 200
        expect(company.groups.count).to eq 1
        group.reload
        expect(group.display_name).to eq "New Display Name"
      end

      it "throws an error for non status updates" do
        patch :patch_update, params: {
          id: 1,
          Operations: [
            {
              op: "replace",
              value: {
                id: 123123
              }
            }
          ]
        }

        expect(response.status).to eq 422
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end
    end
  end


  describe "patch add members" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        patch :patch_update, params: add_members_params(id: 1)

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        patch :patch_update, params: add_members_params(id: 1)

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        patch :patch_update, params: add_members_params(id: 1)

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      let!(:group) { create(:group, id: 1, company: company) }
      let!(:user_1) { create(:user, id: 1, company: company) }
      let!(:user_2) { create(:user, id: 2, company: company) }

      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        patch :patch_update, params: add_members_params(id: 1)

        expect(response.content_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        patch :patch_update, params: add_members_params(id: 1)

        expect(response.status).to eq 200
      end

      it "returns :not_found for id that cannot be found" do
        get :patch_update, params: add_members_params(id: "fake_id")

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1000)

        get :patch_update, params: add_members_params(id: 1000)

        expect(response.status).to eq 404
      end

      it "successfully update group [Add members]" do
        expect(company.groups.count).to eq 1
        group = company.groups.first

        patch :patch_update, params: add_members_params(id: 1, members: [user_1.id])

        expect(response.status).to eq 200
        group.reload
        expect(group.users.count).to eq 1
        expect(group.users).to include user_1
      end

      it "successfully update group [Add members]" do
        expect(company.groups.count).to eq 1
        group = company.groups.first
        group.users = [user_1]

        patch :patch_update, params: add_members_params(id: 1, members: [user_2.id])

        expect(response.status).to eq 200
        group.reload
        expect(group.users.count).to eq 2
        expect(group.users).to include(user_1, user_2)
      end

      it "do nothing if try to add existing user to the group" do
        expect(company.groups.count).to eq 1
        group = company.groups.first
        group.users = [user_1]

        patch :patch_update, params: add_members_params(id: 1, members: [user_1.id])

        expect(response.status).to eq 200
        group.reload
        expect(group.users.count).to eq 1
        expect(group.users).to include(user_1)
      end

      it "throws an error for non status updates" do
        patch :patch_update, params: {
          id: 1,
          Operations: [
            {
              op: "add",
              value: [
                { value: nil }
              ]
            }
          ]
        }

        expect(response.status).to eq 404
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end
    end
  end


  describe "patch remove members" do
    let(:company) { create(:company) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        patch :patch_update, params: remove_members_params(id: 1)

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        patch :patch_update, params: remove_members_params(id: 1)

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        patch :patch_update, params: remove_members_params(id: 1)

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      let!(:group) { create(:group, id: 1, company: company) }
      let!(:user_1) { create(:user, id: 1, company: company) }
      let!(:user_2) { create(:user, id: 2, company: company) }

      before :each do
        http_login(company)
      end

      it "returns scim+json content type" do
        patch :patch_update, params: remove_members_params(id: 1)

        expect(response.content_type).to eq "application/scim+json"
      end

      it "is successful with valid credentials" do
        patch :patch_update, params: remove_members_params(id: 1)

        expect(response.status).to eq 200
      end

      it "returns :not_found for id that cannot be found" do
        get :patch_update, params: remove_members_params(id: "fake_id")

        expect(response.status).to eq 404
      end

      it "returns :not_found for a correct id but unauthorized company" do
        new_company = create(:company)
        create(:group, company: new_company, id: 1000)

        get :patch_update, params: remove_members_params(id: 1000)

        expect(response.status).to eq 404
      end

      it "successfully update group [Remove members]" do
        expect(company.groups.count).to eq 1
        group = company.groups.first
        group.users = [user_1]

        patch :patch_update, params: remove_members_params(id: 1, members: [user_1.id])

        expect(response.status).to eq 200
        group.reload
        expect(group.users.count).to eq 0
        expect(group.users).to eq []
      end

      it "successfully update group [Remove members]" do
        expect(company.groups.count).to eq 1
        group = company.groups.first
        group.users = [user_1, user_2]

        patch :patch_update, params: remove_members_params(id: 1, members: [user_2.id])

        expect(response.status).to eq 200
        group.reload
        expect(group.users.count).to eq 1
        expect(group.users).to include(user_1)
      end

      it "do nothing if try to remove non-member from the group" do
        expect(company.groups.count).to eq 1
        group = company.groups.first
        group.users = [user_1]

        patch :patch_update, params: remove_members_params(id: 1, members: [user_2.id])

        expect(response.status).to eq 200
        group.reload
        expect(group.users.count).to eq 1
        expect(group.users).to include(user_1)
      end

      it "throws an error for non status updates" do
        patch :patch_update, params: {
          id: 1,
          Operations: [
            {
              op: "remove",
              value: [
                { value: nil }
              ]
            }
          ]
        }

        expect(response.status).to eq 404
        response_body = JSON.parse(response.body)
        expect(response_body.dig("schemas", 0)).to eq "urn:ietf:params:scim:api:messages:2.0:Error"
      end
    end
  end


  describe "destroy" do
    let(:group) { create(:group) }

    context "when unauthorized" do
      it "returns scim+json content type" do
        delete :destroy, params: { id: group.id }

        expect(response.content_type).to eq "application/scim+json"
      end

      it "fails with no credentials" do
        delete :destroy, params: { id: group.id }

        expect(response.status).to eq 401
      end

      it "fails with invalid credentials" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials("unauthorized","123456")

        delete :destroy, params: { id: group.id }

        expect(response.status).to eq 401
      end
    end

    context "when authorized" do
      before :each do
        http_login(group.company)
      end

      it "returns nil content type" do
        delete :destroy, params: { id: group.id }

        expect(response.content_type).to eq nil
      end

      it "is successful with valid credentials" do
        company = group.company
        expect(company.groups.count).to eq 1

        delete :destroy, params: { id: group.id }

        expect(response.status).to eq 204
        expect(company.groups.count).to eq 0
      end
    end
  end

  def patch_params(id:, displayName: "Default")
    {
      id: id,
      Operations: [
        {
          op: "replace",
          value: {
            displayName: displayName
          }
        }
      ]
    }
  end

  def add_members_params(id:, members: [1])
    {
      id: id,
      Operations: [
        {
          op: "add",
          value: [
            { value: members }
          ]
        }
      ]
    }
  end

  def remove_members_params(id:, members: [1])
    {
      id: id,
      Operations: [
        {
          op: "remove",
          value: [
            { value: members }
          ]
        }
      ]
    }
  end

  def put_params(displayName: "Default")
    {
      id: 1,
      displayName: displayName
    }
  end
end
