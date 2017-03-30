defmodule Poker.Web.Policy.ProjectMember do
  import Ecto.Query, only: [from: 2, where: 2, preload: 2]
  alias Poker.{Repo, User, Project, OrganizationMember, ProjectMember}

  def can?(nil, action, _resource)
  when action in [:create, :update, :delete], do: false

  def can?(%User{id: user_id}, action, %{organization_id: org_id})
  when action == :create do
    OrganizationMember.member?(org_id, user_id)
  end
  def can?(%User{id: user_id} = user, action, %{project_id: proj_id,
                                                user_id: new_member_id})
  when action in [:create] do
    if ProjectMember.member?(proj_id, user_id) do
      if not ProjectMember.member?(proj_id, new_member_id) do
        true
      else
        {:error, {:bad_request, "user already is a member"}}
      end
    else
      false
    end
  end

  def can?(%User{id: user_id}, action, %{project_id: proj_id})
  when action in [:update, :delete] do
    ProjectMember.member?(proj_id, user_id)
  end

  def can?(_user, _action, _member), do: true
end