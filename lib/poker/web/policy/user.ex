defmodule Poker.Web.Policy.User do
  use Poker.Web, :policy

  alias Poker.User

  def can?(%User{id: user_id}, action, %{user: user})
  when action in [:update, :delete] do
    user_id == user.id
  end

  def can?(_user, _action, _data), do: true
end